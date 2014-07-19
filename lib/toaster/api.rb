
require "thor"
require "xmlrpc/client"
require "toaster/util/util"
require "toaster/util/docker"

include Toaster

module Toaster

  class ToasterApp < Thor

    CMD = "toaster"
    class_option :verbose, :type => :boolean, :aliases => ["-v"]
    ROOT_DIR = File.join(File.dirname(File.expand_path(__FILE__)), "..", "..")
    CHEF_TMP_DIR = "/tmp/toaster.chef"
    `mkdir -p #{CHEF_TMP_DIR}`
    CHEF_TMP_SOLO_FILE = "#{CHEF_TMP_DIR}/solo.rb"
    CHEF_TMP_NODE_FILE = "#{CHEF_TMP_DIR}/node.json"

    # setup host environment
    desc "setup", "Setup the testing host environment. (Should be run on a clean VM, not on production machines)"
    def setup()
      write(CHEF_TMP_NODE_FILE, <<-EOF
      {
        "run_list": ["recipe[lxc::setup_host]"]
      }
      EOF
      )
      run_chef()
    end

    # create new prototype container
    desc "proto NAME [OS_DISTRO]", "Create a new prototype container with given NAME and OS_DISTRO."
    long_desc "Example: #{CMD} proto ubuntu1 ubuntu"
    def proto(prototype_name, operating_system="ubuntu")

      prototype_name = "prototype_#{prototype_name}" if !prototype_name.match(/^prototype_.*/)

      #operating_system = options[:os]
      write(CHEF_TMP_NODE_FILE, <<-EOF
    {
      "run_list": ["recipe[lxc::init_proto]"],
      "lxc": {
        "proto": {
          "name": "#{prototype_name}"
        },
        "bare_os": {
          "distribution": "#{operating_system}"
        }
      }
    }
      EOF
      )
      run_chef()

    end

    # call recipe to create a new container from a prototype
    desc "spawn NAME PROTOTYPE", "Spawn a new container with given NAME, copy of PROTOTYPE."
    long_desc "Example: #{CMD} spawn lxc1 ubuntu1"
    def spawn(lxc_name, prototype_name)

      prototype_name = "prototype_#{prototype_name}"

      prototype_dir = "/lxc/#{prototype_name}"
      if !Dir.exist?(prototype_dir)
        raise "Prototype directory '#{prototype_dir}' does not exist."
      end

      ip_num = ""
      # test if LXC name is "lxc[0-9]+"
      if lxc_name.match(/^lxc[0-9]+$/)
        ip_num = lxc_name.gsub(/lxc([0-9]+)/, '\1').to_i
        ip_num += 2
      end
      if ip_num == ""
        Docker.get_container_names().size() + 3
        ip_num = num_lxcs.to_i + 3
      end
      guest_ip = "192.168.100.#{ip_num}"
    
      content = <<-EOF
      {
        "run_list": ["recipe[lxc::create_lxc]"],
        "lxc": {
          "proto": {
            "name": "#{prototype_name}"
          },
          "cont": {
            "name": "#{lxc_name}",
            "ip_address": "#{guest_ip}"
          }
        }
      }
      EOF
      write(CHEF_TMP_NODE_FILE, content)
      run_chef()
    
    end

    # Run a Chef recipe within a container
    desc "runchef NAME IP CHEF_RUNLIST [CHEF_JSON]", "Run Chef recipe in container with NAME and IP."
    long_desc "Example: #{CMD} lxc1 192.168.100.2 recipe[java] \\\"foo1\\\":\\\"bar\\\",\\\"foo2\\\":\\\"bar\\\""
    def runchef(lxc_name, lxc_ip, run_list, cfg="")

      if cfg != ""
        cfg = ", #{cfg}"
        cfg = cfg.gsub(/"/, '\\\\"')
      end
      if Dir.exist?("/lxc/#{lxc_name}/rootfs/")
        tmpf = `mktemp`
        tmpf1 = `mktemp`
        tmpf.strip!
        tmpf1.strip!
        tmpfile = "/lxc/#{lxc_name}/rootfs/#{tmpf}"
        tmpfile1 = "/lxc/#{lxc_name}/rootfs/#{tmpf1}"
        write(tmpfile, "{\"run_list\": [\"#{run_list}\"] #{cfg}}")
        `cp #{CHEF_TMP_SOLO_FILE} #{tmpfile1}`
        puts "INFO: Created config file #{tmpfile}: #{`cat #{tmpfile}`}"
        system("ssh root@#{lxc_ip} chef-solo -j #{tmpf} -c #{tmpf1}")
        `rm -f #{tmpfile} #{tmpfile1}`
      else
        puts "ERROR: container directory /lxc/#{lxc_name}/rootfs/ does not exist."
      end
    end

    # initiate a local chef-solo run
    desc "chefsolo NODE_FILE", "Initiate a local chef-solo run with the given NODE_FILE."
    long_desc "Example: #{CMD} chefsolo /tmp/chef.node.json"
    def chefsolo(node_file)
      require "toaster/chef/chef_util"
      require "toaster/util/util"
      solo_file = CHEF_TMP_SOLO_FILE
      Toaster::ChefUtil.create_chef_config(solo_file)
      Toaster::ChefUtil.run_chef(solo_file, node_file)
    end

    # Start an existing container
    desc "start NAME", "Start container with given NAME."
    def start(lxc_name)
      start_stop_container("start", lxc_name)
    end

    # Stop an existing container
    desc "stop NAME", "Stop container with given NAME."
    def stop(lxc_name)
      start_stop_container("stop", lxc_name)
    end

    # run tests of a specific test suite
    desc "runtests TEST_SUITE", "Run test cases of the given TEST_SUITE."
    #option :idemN, :type => :array, :desc => "idempotence for task sequences of length N (N is an array)"
    #option :skipN, :type => :array, :desc => "skip N tasks (N is an array)"
    #option :skipNsucc, :desc => "skip N successive tasks (N is an array)"
    #option :combineN, :desc => "combine N tasks (N is an array)"
    #option :combineNsucc, :desc => "combine N successive tasks (N is an array)"
    def runtests(test_suite_uuid, idem_N=(1..100).to_a, 
        skip_N=[], skip_N_succ=[], combine_N=[], combine_N_succ=[])

      require "toaster/test/test_suite"
      require "toaster/test/test_coverage"
      require "toaster/test/test_orchestrator"

      #idem_N = options[:idemN]
      #skip_N = options[:skipN]
      #skip_N_succ = options[:skipNsucc]
      #combine_N = options[:combineN]
      #combine_N_succ = options[:combineNsucc]
      if idem_N
        if idem_N.include?("..")
          idem_N = eval("#{idem_N}").to_a.join(",")
        elsif !idem_N.kind_of?(Array)
          idem_N = [idem_N.to_i]
        end
      end
    
      init_db_connection()
      test_suites = Toaster::TestSuite.find({"uuid" => test_suite_uuid})
      if !test_suites || test_suites.empty?
        puts "ERROR: Invalid test suite id specified: '#{test_suite_uuid}'"
      else
        puts "INFO: Running/continuing tests for test suite '#{test_suite_uuid}'"
        test_suite = test_suites[0]
        test_suite.coverage_goal.idempotence = idem_N if idem_N
        test_suite.coverage_goal.combinations[Toaster::CombinationCoverage::SKIP_N] = skip_N if skip_N
        test_suite.coverage_goal.combinations[Toaster::CombinationCoverage::SKIP_N_SUCCESSIVE] = skip_N_succ if skip_N_succ
        test_suite.coverage_goal.combinations[Toaster::CombinationCoverage::COMBINE_N] = combine_N if combine_N
        test_suite.coverage_goal.combinations[Toaster::CombinationCoverage::COMBINE_N_SUCCESSIVE] = combine_N_succ if combine_N_succ
        test_suite.save()
        orch = Toaster::TestOrchestrator.new
        orch.generate_tests_for_suite(test_suite)
        if Config.get("testing.test_hosts").kind_of?(Array)
          Config.get("testing.test_hosts").each do |test_host|
            orch.add_host(test_host)
          end
        end
        orch.distribute_tests(test_suite)
      end
    end

    # download Chef recipe into container
    desc "download COOKBOOK PROTOTYPE [VERSION] [RECIPES]", "Download Chef COOKBOOK into PROTOTYPE."
    #option :version, :desc => "Cookbook version to download", :default => "latest"
    #option :recipes, :type => :array, :desc => "List of recipes", :default => ["default"]
    def download(cookbook, prototype_name, version="latest", recipes=["default"])

      require "toaster/chef/chef_util"
      require "toaster/util/lxc"

      recipes = parse_recipes(recipes)
      prototype_name_full = prototype_name
      prototype_name_full = "prototype_#{prototype_name_full}" if !prototype_name_full.match(/^prototype_/)
      start_stop_container("start", prototype_name_full)
    
      lxc = Toaster::LXC.prototype_container(prototype_name)
      puts "INFO: Ensuring existence of latest cookbooks and node file in LXC container '#{lxc['lxc_id']}'"
      Toaster::ChefUtil.download_cookbook_version_in_lxc(lxc, cookbook, version)
      cookbook_dir = Toaster::ChefUtil.lxc_cookbook_dir(lxc)
      # clean cookbooks
      Toaster::ChefUtil.fix_known_bugs_in_recipes(cookbook_dir, "before")
      # dowload dependencies for cookbook
      Toaster::ChefUtil.download_dependencies(cookbook, nil, cookbook_dir, true)
      # additionally, check dependencies for each recipe
      recipes.each do |recipe|
        Toaster::ChefUtil.download_dependencies(cookbook, recipe, cookbook_dir, false)
      end
      # fix cookbook bugs, encodings, etc.
      Toaster::ChefUtil.fix_known_bugs_in_recipes(cookbook_dir, "after")

      start_stop_container("stop", prototype_name_full)

      # if we are using docker.io tools, the changes made to 
      # the container need to be saved (committed) explicitly... 
      Docker.save_container_changes(prototype_name_full)
    end

    # Initialize a test suite
    desc "testinit CHEF_NODE RECIPES PROTOTYPE", "Initialize a test suite for the given CHEF_NODE and RECIPES, running within PROTOTYPE. (params: --destroy=true)"
    long_desc "Example: #{CMD} testinit --destroy=true mysql default ubuntu1"
    #option :destroy, :type => :boolean, :desc => "Destroy container after execution", :default => true
    def testinit(chef_node, recipes, prototype, destroy_container=true)

      require "toaster/test_manager"

      #destroy_container = options[:destroy]
      recipes = parse_recipes(recipes)
      puts "INFO: Ensuring existence of automation #{chef_node}, recipe list '#{recipes}', prototype #{prototype} (destroy container: #{destroy_container})"
    
      init_db_connection()
      do_output = true
      suite = Toaster::TestManager.init_test(chef_node, recipes, nil, prototype, destroy_container, do_output)

      if suite && suite.uuid
        puts "INFO: New test suite UUID: #{suite.uuid}"
      else
        puts "WARN: Could not initialize test suite, test manager returned empty test suite UUID."
      end
    end

    # start the test service in the background
    desc "agent", "Start the test service process in the background."
    def agent()
      require "toaster/toaster_app_service"
      ToasterAppService.start_service()
    end
  
    # Clean spawned containers
    desc "clean", "Clean all spawned containers (prototypes will be preserved)."
    def clean()
      require "toaster/util/lxc"
      Toaster::LXC.clean()
    end

    # Print version information
    desc "version", "Print version of ToASTER."
    def version()
      file = File.join(File.dirname(__FILE__), "..", "..", "VERSION")
      version = File.read(file)
      puts version
      return "#{version}".strip
    end

    # Start web app
    desc "web", "Start the Web application. (params: --detached=false)"
    option :detached, :type => :boolean, :aliases => ["-d"]
    def web(detached=false)
      puts "INFO: Starting Web application on port 8080"
      dir = File.join(File.dirname(__FILE__), "..", "..")
      cmd = "cd \"#{dir}\" && #{dir}/webapp/bin/rails server thin"
      detached ||= options[:detached]
      if detached
        Kernel::exec("screen -d -m bash -c '#{cmd}'")
      else
        Kernel::exec("#{cmd}")
      end
    end

    #####################
    # NON-CLI FUNCTIONS #
    #####################
    # (accessible from toaster_app_service)

    no_commands {

    def lxc()
      execute("ls -l /lxc/")
      execute("lxc-ls; echo \"__--__ \"; sh -c 'cat /lxc/*/config' 2>&1")
    end

    def runtest(test_case_uuid, blocking=true, num_threads=nil)

      require "toaster/test/test_case"
      init_db_connection()
      test_case_uuids = test_case_uuid.split(/[ ;,]+/)
      test_cases = TestCase.find(:uuid => test_case_uuids[0]).to_a
      if !test_cases || test_cases.empty?
        puts "ERROR: Invalid test case id(s) specified: '#{test_case_uuid}'"
        puts "database: #{Toaster::Config.get("db.host")}"
      else
        
        # set the start time of all test cases. This is important
        # because it allows to indicate in the UI that the test cases 
        # are currently running
        time = Toaster::TimeStamp.now
        test_case_uuids.each do |uuid|
          tc = TestCase.find(:uuid => uuid)[0]
          tc.start_time = time
          tc.save
        end

        test_case = test_cases[0]
        test_suite = test_case.test_suite
        test_suite_uuid = test_suite.uuid
        if blocking
          print_output = true
          destroy_container = true
          TestRunner.execute_test(test_case, destroy_container, print_output)
        else
          puts "INFO: Scheduling test cases #{test_case_uuids} for test suite uuid '#{test_suite_uuid}'"
          if $test_runners[test_suite_uuid]
            runner = $test_runners[test_suite_uuid]
            runner.schedule_tests(test_suite, test_case_uuids)
          else
            runner = TestRunner.new(test_suite, num_threads, true)
            runner.schedule_tests(test_suite, test_case_uuids)
            runner.start_worker_threads()
            $test_runners[test_suite_uuid] = runner
          end
        end
      end
    end

    }

    ####################
    # HELPER FUNCTIONS #
    ####################

    private
    
    def download_script(file)
      puts "Downloading #{SCRIPTSERVER}/#{file} to /tmp/#{file}"
      `wget -q #{SCRIPTSERVER}/#{file} -O /tmp/#{file}`
      `chmod +x /tmp/#{file}`
    end
    def write(filename, content)
      Util.write(filename, content, true)
    end
    def run_chef(run_list="", print_output=true)
      if "#{run_list}" != ""
        write(CHEF_TMP_NODE_FILE, <<-EOF
        {
          "run_list": #{run_list}
        }
        EOF
        )
      end
      puts "INFO: Running Chef scripts..."
      require "toaster/chef/chef_util"
      Toaster::ChefUtil.run_chef(CHEF_TMP_SOLO_FILE, CHEF_TMP_NODE_FILE, print_output)
    end
    def parse_recipes(arg)
      return [] if !arg || arg.to_s.strip == ""
      return arg if arg.kind_of?(Array)
      recipes = arg.split(/[ ,;:]+/)
      recipes = ["default"] if recipes.empty?
      recipes
    end
    def init_db_connection()
      Toaster::Config.init_db_connection()
    end
    def start_stop_container(action, lxc_name)

      if !Dir.exist?("/lxc/#{lxc_name}")
        puts "ERROR: Container directory does not exist: /lxc/#{lxc_name}"
        exit 1
      end
      guest_ip = `cat /lxc/#{lxc_name}/config | grep "network.ipv4" | tail -n 1`
      guest_ip.gsub!(/.*=\s([0-9\.]*).*/, '\1').strip!()

      puts "DEBUG: #{action} container named '#{lxc_name}' with IP '#{guest_ip}'"

      # get config value
      proxy_ip = Config.get("proxy.ip")

      write(CHEF_TMP_NODE_FILE, <<-EOF
    {
      "run_list": ["recipe[lxc::#{action}_lxc]"],
      "lxc": {
        "cont": {
          "name": "#{lxc_name}",
          "ip_address": "#{guest_ip}",
          "proxy_ip": "#{proxy_ip}"
        }
      }
    }
    EOF
    )
      run_chef("", false)
    end

  end

  class ToasterAppClient < XMLRPC::Client
    attr_reader :host, :port

    def initialize(host, port=8385)
      @host = host.include?(":") ? host.gsub(/([^:]+):.*/, '\1') : host
      @port = host.include?(":") ? host.gsub(/([^:]+):(.+)/, '\2') : port
      @port = @port.to_i
      super(@host, "/", @port)
      self.timeout = 60*60 # timeout of 1h for RPC calls
    end
    def method_missing(name, *args, &block)
      call(name, *args, &block)
    end
    def to_s
      "ServiceProxy<#{host}:#{port}>"
    end

  end

end
