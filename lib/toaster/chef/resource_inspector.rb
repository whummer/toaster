

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require 'chef/log'
require 'chef/run_context'
require 'chef/client'
require 'chef/application/solo'
require 'toaster/chef/chef_util'
require 'toaster/markup/markup_util'
require "toaster/model/task_parameter"
require "toaster/model/task"

module Toaster
  class ResourceInspector

    STATECHANGE_PACKAGES = "packages"
    STATECHANGE_PORTS = "ports"
    STATECHANGE_FILES = "files"
    STATECHANGE_GEMS = "gems"
    STATECHANGE_MOUNTS = "mounts"
    STATECHANGE_USERS = "users"
    STATECHANGE_GROUPS = "groups"
    STATECHANGE_CRON = "cron"
    STATECHANGE_SERVICES = "services"
    STATECHANGE_ROUTES = "routes"
    STATECHANGE_MYSQL = "mysql"
    STATECHANGE_APACHE = "apache"
    STATECHANGE_IPTABLES = "iptables"

    @@initialized = false
    #@@state_config_cache = {} # caching doesn't work here anymore

    def self.get_accessed_parameters(task_or_sourcecode, cookbook_paths = [])
      result = []
      resource_src = task_or_sourcecode.respond_to?("sourcecode") ? 
          task_or_sourcecode.sourcecode : task_or_sourcecode.to_s
      symbol = ":[a-zA-Z0-9_]+"
      numeric_index = "[0-9]+"
      quoted_string1 = '"[^\\]]+"'
      quoted_string2 = "'[^\\]]+'"
      resource_src.scan(/node((\[((#{symbol})|(#{numeric_index})|(#{quoted_string1})|(#{quoted_string2}))\][ \t]*)+)/).each do |param|
        param = param[0].strip
        param = MarkupUtil.convert_array_to_dot_notation(param)
        if task_or_sourcecode.kind_of?(Task)
          param = TaskParameter.new(task_or_sourcecode, param)
        else
          param = TaskParameter.new(:key => param)
        end
        exists = result.find { |p| (p.kind_of?(TaskParameter) ? p.key : p) == 
            (param.kind_of?(TaskParameter) ? param.key : param) }
        #puts "exists: #{param} - #{exists}"
        if !exists
          result << param
        end
      end
      return result
    end

    #
    # Returns a hash which maps identifier=>configurations, indicating which types 
    # of state changes this task, upon execution, is *potentially* going to 
    # perform. For instance, if the task starts/stops a system service,
    # the identifier "ports" will be in the hash keys. If the task modifies 
    # some files, the key will contain the identifier "files", and possibly a list of
    # potential files that may be edited. 
    # This helps us to develop tailor-made state capturing tools (e.g., implemented 
    # as ohai plugins) for different types of tasks.
    # 
    def self.get_config_for_potential_state_changes(task_or_sourcecode, 
          cookbook_paths = [], state_change_config = {})
      data = parse_data(task_or_sourcecode, cookbook_paths, state_change_config)
      return data[0]
    end

    def self.guess_potential_state_changes(task_or_sourcecode, cookbook_paths = [], state_change_config = {})
      data = parse_data(task_or_sourcecode, cookbook_paths, state_change_config)
      return data[1]
    end

    def self.get_resource_from_source(resource_src, attribute_src, cookbook_paths = [])
      resource = nil
    
      # we are performing multiple parsing attempts. if parsing goes well, 
      # the resource is returned. however, if a parsing error occurs, we 
      # investigate the error message, and for missing variables we add a default 
      # initializer to the beginning of the source code. Then, we re-attempt 
      # to parse the code.
      # The maximum number of such attempts is defined here.
      max_attempts = 20

      chef_client_json = { 
        "platform" => "ubuntu", 
        "platform_version" => "12.04",
        "kernel" => { "machine" => "x86_64" },
        "log_level" => :fatal,
        "ipaddress" => ""
      }

      # define some inits in script source:
      preamble = "
            require 'toaster/chef/chef_node_inspector'
            $old_node = node
            $new_node = Toaster::DefaultProcessorRecursive.new(
                #{chef_client_json.inspect})

            require 'toaster/chef/failsafe_resource_parser'

            $old_node.attributes_proxy = $new_node
            node = $new_node
            template = $new_node
            self.attributes_proxy = $new_node
            "

      attribute_src = 
        "#{preamble} #{attribute_src}"
#      resource_src = 
#        "#{preamble} #{resource_src}"

      #puts "getting resource source: #{resource_src}\n---"

      max_attempts.downto(1) do |attempt|
    
        Tempfile.open("chef.resource.rb") do |file|
          file.write(resource_src)
          file.flush
    
          Tempfile.open("chef.attributes.rb") do |file1|
            file1.write(attribute_src)
            file1.flush
    
            orig_log_level = ChefUtil.get_chef_log_level()
    
            begin
    
              ChefUtil.set_chef_log_level(:fatal)

              if !@@initialized
                chef_cfg = Chef::Config
                chef_cfg[:solo] = true
                chef_cfg[:node_name] = "foobar"
                path_new = []
                chef_cfg[:cookbook_path].each do |p|
                  path_new << p if File.directory?(p)
                end
                chef_cfg[:cookbook_path] = path_new
                chef_cfg[:cookbook_path] << File.expand_path(File.join(File.dirname(__FILE__), 'cookbooks'))
                chef_cfg[:cookbook_path].concat(cookbook_paths)
                chef_cfg[:log_level] = :fatal
                chef_cfg[:verbose_logging] = false
                Chef::Application::Solo.new # this initializes some important state variables

                @@chef_client = Chef::Client.new(
                  chef_client_json
                )
                begin
                  @@node = @@chef_client.build_node
                rescue
                  # required to avoid exception in Chef 11.12.8
                  @@node = @@chef_client.policy_builder.load_node
                end
                @@cookbook_collection = Chef::CookbookCollection.new(
                Chef::CookbookLoader.new(chef_cfg[:cookbook_path]))
    
                @@initialized = true
              end

              if attribute_src && attribute_src.to_s.strip != ""
                @@node.from_file(file1.path)
              end

              run_context = nil
              begin
                run_context = Chef::RunContext.new(@@node, @@cookbook_collection)
              rescue
                # required to avoid exception in Chef 11.12.8
                run_context = Chef::RunContext.new(@@node, @@cookbook_collection, nil)
              end
              recipe = Chef::Recipe.new("apache2", "default", run_context)
              recipe.from_file(file.path)

              #puts "getting resource from recipe #{recipe}"
              resource = recipe.run_context.resource_collection.all_resources[0]
              #puts "returning resource: #{resource}"
              #puts "--> #{recipe.run_context.resource_collection.all_resources}"
    
              return resource
            rescue Object => ex
              msg = ex.to_s
              puts msg if attempt <= 1
              puts ex.backtrace if attempt <= 1

              if msg.match(/Cannot find a resource for/)
                pkg_name = msg.gsub(/.*for ([a-z0-9A-Z_]+) on.*/, '\1').to_s
                resource_src = "#{pkg_name} = \"initializer_for_unknown_variable_#{pkg_name}\" \n #{resource_src}"
              elsif msg.match(/undefined (local variable or )?method/)
                var_name = msg.gsub(/.*method `([a-z0-9A-Z_]+).* for.*/, '\1').to_s
                resource_src = "#{var_name} = \"initializer_for_unknown_variable_#{var_name}\" \n #{resource_src}"
              elsif msg.match(/No resource or method named `([a-z0-9A-Z_]+)' for/)
                res_name = msg.gsub(/.*No resource or method named `([a-z0-9A-Z_]+)' for.*/, '\1').to_s
                tmp_class_name = "MyResource#{Util.generate_short_uid()}"
                resource_src = 
                "class #{tmp_class_name} < Chef::Resource
                  def initialize(name = nil, run_context = nil)
                    super
                    @resource_name = :#{res_name}
                    @enclosing_provider_fixed = DefaultProcessorRecursive.new
                    @enclosing_provider_fixed.swallow_calls_hash = {}
                  end
                  def enclosing_provider
                    @enclosing_provider_fixed
                  end
                  def action(arg=nil)
                    self.allowed_actions << arg
                    super
                  end
                end
                #{tmp_class_name}.provides(:#{res_name})
                #{resource_src}"
              elsif msg.match(  /resource matching/)
                regex = /.*resource matching (.*)\[(.*)\].*/
                res_type = msg.gsub(regex, '\1').to_s
                res_name = msg.gsub(regex, '\2').to_s
                resource_src = "#{res_type} \"#{res_name}\" do \n end \n\n #{resource_src}"
              else
                puts "ERROR: Could not get Chef resource object from source code: #{msg}"
                puts ex.backtrace.join("\n")
                puts File.read(file.path)
                puts "---------"
                puts File.read(file1.path)
                puts "---------"
                return nil
              end
            ensure
              ChefUtil.set_chef_log_level(orig_log_level)
            end
          end
        end
      end
      return resource
    end

    private

    def self.parse_data(task_or_sourcecode, cookbook_paths = [], state_change_config = {})

      resource_src = task_or_sourcecode.respond_to?("sourcecode") ? 
          task_or_sourcecode.sourcecode : task_or_sourcecode.to_s
      resource_obj = task_or_sourcecode.respond_to?("resource_obj") ? 
          task_or_sourcecode.resource_obj : nil
      attribute_src = nil

      # unfortunately, we cannot do caching anymore. Otherwise, we would lose 
      # potential new configurations in the state_change_config parameter..!
      #return @@state_config_cache[resource_src] if @@state_config_cache[resource_src]

      #puts "task_or_sourcecode.respond_to... #{task_or_sourcecode.respond_to?("sourcefile")} #{task_or_sourcecode}"
      if task_or_sourcecode.respond_to?("sourcefile")
        recipe_file = ChefUtil.get_absolute_file_path(cookbook_paths, task_or_sourcecode.sourcefile)
        #puts "INFO: Chef recipe file: #{recipe_file}"
        if recipe_file
          attribute_file = ChefUtil.get_attribute_file(recipe_file)
          #puts "INFO: Chef attribute file: #{attribute_file}"
          if attribute_file && File.exist?(attribute_file)
            if File.directory?(attribute_file)
              puts "WARN: Chef attributes file is actually a directory: #{attribute_file}"
            else
              attribute_src = File.read(attribute_file)
            end
          end
        end
      end

      resource = resource_obj ? resource_obj :
           get_resource_from_source(resource_src, attribute_src, cookbook_paths)

      if !resource
        error = "ERROR: unable to convert source code to resource."
        puts error
        puts resource_src
        puts "---"
        puts attribute_src
        puts "----"
        raise error
      end

      config = state_change_config ? state_change_config : {}
      expected_state_changes = []

      chef_resource_class = Chef::Resource

      if resource.kind_of?(chef_resource_class::Script) ||
          resource.kind_of?(chef_resource_class::Execute) ||
          resource.kind_of?(chef_resource_class::Bash)

        code = resource.respond_to?("code") ? resource.code : resource.command
        code = "#{code}\n------\n'#{resource.to_text}'" if resource.respond_to?("to_text")

        # characters that may occur before/after certain commands
        # that we search for within the script code
        b = "[^a-zA-Z0-9_\\-]"
        a = "[^a-zA-Z0-9_\\-]"

        # try to guess some semantics of the script by 
        # performing simple string pattern checks
        if code.match(/(^|#{b}+)mount\s+.*/)
          config[STATECHANGE_MOUNTS] = {} if !config[STATECHANGE_MOUNTS]
          expected_state_changes << StateChange.new(
                :property => STATECHANGE_MOUNTS, 
                :action => StateChange::ACTION_INSERT, 
                :value => StateChange::VALUE_UNKNOWN)
        end
        if code.match(/(^|#{b}+)umount\s+.*/)
          config[STATECHANGE_MOUNTS] = {} if !config[STATECHANGE_MOUNTS]
          expected_state_changes << StateChange.new(
                :property => STATECHANGE_MOUNTS, 
                :action => StateChange::ACTION_DELETE, 
                :value => StateChange::VALUE_UNKNOWN)
        end
        if code.match(/(^|#{b}+)gem((\s+)|((\s+).*(\s+)))install.*/)
          config[STATECHANGE_GEMS] = {} if !config[STATECHANGE_GEMS]
          expected_state_changes << StateChange.new(
                :property => STATECHANGE_GEMS, 
                :action => StateChange::ACTION_INSERT, 
                :value => StateChange::VALUE_UNKNOWN)
        end
        if code.match(/(^|#{b}+)gem((\s+)|((\s+).*(\s+)))uninstall.*/)
          config[STATECHANGE_GEMS] = {} if !config[STATECHANGE_GEMS]
          expected_state_changes << StateChange.new(
                :property => STATECHANGE_GEMS, 
                :action => StateChange::ACTION_DELETE, 
                :value => StateChange::VALUE_UNKNOWN)
        end
        if  code.match(/(^|#{b}+)yum\s+.*/) ||
            code.match(/(^|#{b}+)apt-get\s+.*/) ||
            code.match(/(^|#{b}+)dpkg\s+.*/)
          config[STATECHANGE_PACKAGES] = {} if !config[STATECHANGE_PACKAGES]
        end
        if  code.match(/(^|#{b}+)route\s+.*/)
          config[STATECHANGE_ROUTES] = {} if !config[STATECHANGE_ROUTES]
        end
        if  code.match(/(^|#{b}+)netcat($|#{a}+)/)
          config[STATECHANGE_PORTS] = {} if !config[STATECHANGE_PORTS]
        end
        if code.match(/(^|#{b}+)(\/usr\/bin\/)*mysql\s+.*/) ||
            code.match(/(^|#{b}+)(\/usr\/bin\/)*mysqladmin\s+.*/) ||
            code.match(/(^|#{b}+)Mysql.new.*/)
          config[STATECHANGE_MYSQL] = {} if !config[STATECHANGE_MYSQL]
        end
        if code.match(/(^|#{b}+)a2enmod\s+.*/) || 
            code.match(/(^|#{b}+)a2dismod\s+.*/) || 
            code.match(/(^|#{b}+)a2ensite\s+.*/) || 
            code.match(/(^|#{b}+)a2dissite\s+.*/)
          config[STATECHANGE_APACHE] = {} if !config[STATECHANGE_APACHE]
        end
        if  code.match(/(^|#{b}+)rebuild-iptables.*/) || 
            code.match(/(^|#{b}+)iptables\s+.*/)|| 
            code.match(/(^|#{b}+)iptables-restore.*/)
          config[STATECHANGE_IPTABLES] = {} if !config[STATECHANGE_IPTABLES]
        end

        files = []
        # put all file-related checks below this line ...
        code.scan(/(^|[\s"']+)([\/a-zA-Z0-9\._\-]+)($|[\s"']+)/) { 
          |start,fname,str_end,full_string|
            if fname
              files << fname.gsub(/["']+/,"").strip 
            end
        }
        code.scan(/(^|#{b}+)((rm)|(mkdir)|(touch))\s+(\-[a-z]+\s+)*['"]*(.*)['"]*/) { 
          |start,cmds,cmd1,cmd2,cmd3,args,fname,full_string|
            if fname
              files << fname.gsub(/["']+/,"").strip 
            end
        }
        if code.match(/(^|#{b}+)((creates)|(cwd))\s+(\-[a-z]+\s+)*['"]*(.*)['"]*/)
          code.scan(/(^|#{b}+)((creates)|(cwd))\s+(\-[a-z]+\s+)*['"]*(.*)['"]*/) { 
            |start,cmds,cmd1,cmd2,args,fname,full_string|
              if fname
                files << fname.gsub(/["']+/,"").strip
              end
          }
        end
        code.scan(/(^|#{b}+)((mv)|(cp)|(ln))\s+(\-[a-z]+\s+)*['"]*(.*)['"]*\s+['"]*(.*)['"]*/) { 
          |start,cmds,cmd1,cmd2,cmd3,args,fname1,fname2,full_string|
            if fname1
              files << fname1.gsub(/["']+/,"").strip 
            end
            if fname2
              files << fname2.gsub(/["']+/,"").strip
            end
        }
        code.scan(/\.exist[s]?\?[\s\(]+([^\)]+)[\s\)$]/) { 
          |fname,full_string| files << fname.gsub(/["']+/,"") 
        }
        if !files.empty?
          #puts "DEBUG: Potential list of files extracted from file commands (e.g., rm,mkdir,touch,...): #{files.inspect}"
          #puts "DEBUG: Source code is: #{code}"
          #puts "DEBUG: -----------"
          config[STATECHANGE_FILES] = {} if !config[STATECHANGE_FILES]
          config[STATECHANGE_FILES]["paths"] = [] if !config[STATECHANGE_FILES]["paths"]
          files.each do |f|
            config[STATECHANGE_FILES]["paths"] << f
          end
          # remove duplicates
          config[STATECHANGE_FILES]["paths"].uniq!
        end
      end

      if resource.kind_of?(chef_resource_class::Package) && 
          !resource.kind_of?(chef_resource_class::GemPackage)
        config[STATECHANGE_PACKAGES] = {} if !config[STATECHANGE_PACKAGES]
        action =  [:install].include?(resource.action) ? StateChange::ACTION_INSERT : 
                  [:upgrade, :reconfig].include?(resource.action) ? StateChange::ACTION_MODIFY : 
                  [:remove, :purge].include?(resource.action) ? StateChange::ACTION_DELETE : 
                  StateChange::ACTION_UNKNOWN
        expected_state_changes << StateChange.new(
              :property => STATECHANGE_PACKAGES, 
              :action => action, 
              :value => resource.package_name)
      end

      if resource.kind_of?(chef_resource_class::YumPackage)
        # already covered by Chef::Resource::Package
      end

      if resource.kind_of?(chef_resource_class::GemPackage)
        config[STATECHANGE_GEMS] = {} if !config[STATECHANGE_GEMS]
        action =  [:install].include?(resource.action) ? StateChange::ACTION_INSERT : 
                  [:upgrade, :reconfig].include?(resource.action) ? StateChange::ACTION_MODIFY : 
                  [:remove, :purge].include?(resource.action) ? StateChange::ACTION_DELETE : 
                  StateChange::ACTION_UNKNOWN
        expected_state_changes << StateChange.new(
              :property => STATECHANGE_GEMS, 
              :action => action, 
              :value => resource.package_name)
      end

      if resource.kind_of?(chef_resource_class::File) ||
          resource.kind_of?(chef_resource_class::Directory)
        config[STATECHANGE_FILES] = {} if !config[STATECHANGE_FILES]
        config[STATECHANGE_FILES]["paths"] = [] if !config[STATECHANGE_FILES]["paths"]
        config[STATECHANGE_FILES]["paths"] << resource.path
        action =  [:create, :touch, :create_if_missing].include?(resource.action) ? StateChange::ACTION_INSERT : 
                  [:delete].include?(resource.action) ? StateChange::ACTION_DELETE : 
                  StateChange::ACTION_UNKNOWN
        expected_state_changes << StateChange.new(
              :property => STATECHANGE_FILES,
              :action => action, 
              :value => resource.path)
      end

      if resource.kind_of?(chef_resource_class::RemoteFile)
        # already covered by Chef::Resource::File
      end

      if resource.kind_of?(chef_resource_class::Link)
        config[STATECHANGE_FILES] = {} if !config[STATECHANGE_FILES]
        config[STATECHANGE_FILES]["paths"] = [] if !config[STATECHANGE_FILES]["paths"]
        config[STATECHANGE_FILES]["paths"] << resource.target_file
        action =  [:create].include?(resource.action) ? StateChange::ACTION_INSERT : 
                  [:delete].include?(resource.action) ? StateChange::ACTION_DELETE : 
                  StateChange::ACTION_UNKNOWN
        expected_state_changes << StateChange.new(
            :property => STATECHANGE_FILES, 
            :action => action, 
            :value => resource.target_file)
      end

      if resource.kind_of?(chef_resource_class::User)
        config[STATECHANGE_USERS] = {} if !config[STATECHANGE_USERS]
      end

      if resource.kind_of?(chef_resource_class::Group)
        config[STATECHANGE_GROUPS] = {} if !config[STATECHANGE_GROUPS]
      end

      if resource.kind_of?(chef_resource_class::Cron)
        config[STATECHANGE_CRON] = {} if !config[STATECHANGE_CRON]
      end

      if resource.kind_of?(chef_resource_class::Mount)
        config[STATECHANGE_MOUNTS] = {} if !config[STATECHANGE_MOUNTS]
        action =  [:mount, :enable].include?(resource.action) ? StateChange::ACTION_INSERT : 
                  [:umount, :disable].include?(resource.action) ? StateChange::ACTION_DELETE : 
                  StateChange::ACTION_UNKNOWN
        expected_state_changes << StateChange.new(
              :property => STATECHANGE_MOUNTS, 
              :action => action, 
              :value => resource.mount_point)
      end

      if resource.kind_of?(chef_resource_class::Service)
        config[STATECHANGE_SERVICES] = {} if !config[STATECHANGE_SERVICES]
        config[STATECHANGE_PORTS] = {} if !config[STATECHANGE_PORTS]
        action =  [:enable, :start, :restart, :reload].include?(resource.action) ? StateChange::ACTION_INSERT : 
                  [:disable, :stop].include?(resource.action) ? StateChange::ACTION_DELETE : 
                  StateChange::ACTION_UNKNOWN
        expected_state_changes << StateChange.new(
              :property => STATECHANGE_SERVICES, 
              :action => action, 
              :value => resource.service_name)
      end

      if resource.kind_of?(chef_resource_class::Route)
        config[STATECHANGE_ROUTES] = {} if !config[STATECHANGE_ROUTES]
        action =  [:add].include?(resource.action) ? StateChange::ACTION_INSERT : 
                  [:delete].include?(resource.action) ? StateChange::ACTION_DELETE : 
                  StateChange::ACTION_UNKNOWN
        expected_state_changes << StateChange.new(
              :property => STATECHANGE_ROUTES, 
              :action => action, 
              :value => resource.target)
      end

      if config.empty?
        puts "WARN: Unable to determine potential state changes for automation task type '#{resource.class}'"
      end

      #puts "State change config: #{config.inspect}"

      entry = [ config , expected_state_changes ]
      #@@state_config_cache[resource_src] = entry #don't do caching..

      return entry
    end

  end
end
