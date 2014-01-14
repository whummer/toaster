

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "rubygems"
require "uri"
require "toaster/util/util"
require "toaster/test/test_suite"
require "toaster/api.rb"

module Toaster

  class TestAgent

    @@root = File.expand_path("web", File.dirname(__FILE__))
    @@port = 8385

    attr_accessor :host, :port, :hostname

    def initialize(host, port = @@port)
      @port = port
      @hostname = host
      if host.match(/:/)
        @hostname = host.gsub(/(.*):.*/, '\1')
        @port = host.gsub(/.*:(.*)/, '\1').to_i
      end
      @host = "#{@hostname}:#{@port}"
      @client = Toaster::ToasterAppClient.new(@hostname, @port)
    end

    ## instance methods for agent proxy (connects to a remote agent)

    def download_scripts(prototype_name, cookbook, recipe_for_dependency_lookup, version="latest")
      @client.download(cookbook, prototype_name, version, recipe_for_dependency_lookup)
    end

    def init_test(prototype_name, cookbook, recipes, destroy_lxc = 1, ignore_props=[])
      destroy_lxc = (![nil,0,false].include?(destroy_lxc)) ? 1 : 0
      suites_before = TestSuite.get_uuids()
      output = @client.testinit(cookbook, recipes, prototype_name, destroy_lxc)
      suites_after = TestSuite.get_uuids()
      if suites_before.size >= suites_after.size
        puts "WARN: test init output >>\n#{output}\n<< end of test init output"
        return output
      end
      puts "INFO: test init output >>\n#{output}\n<< end of test init output" 
      test_suite_uuid = (suites_after - suites_before)[0]
      if ignore_props
        suite = TestSuite.find({"uuid"=>test_suite_uuid})[0]
        suite.automation.ignore_properties.concat(ignore_props)
        suite.automation.ignore_properties.uniq!
        suite.automation.save
      end
      return test_suite_uuid
    end

    def run_test(test_case_uuid)
      @client.runtest(test_case_uuid)
    end

    def exec(command)
      @client.exec(command)
    end

    def clean()
      @client.clean()
    end

    ## class methods

    public

    def self.agent_started?()
      output = `ps aux | grep -v "ps aux" | grep ruby | grep agent_service`
      return output.strip != ""
    end

    def self.start_agent()
      if !agent_started?()
        dir = File.expand_path(File.dirname(__FILE__))
        Util.write("/tmp/toaster.agent.loop.sh",
          "#!/bin/bash\n " +
          "cd #{dir}\n " +
          "while [ 1 ]; do\n " +
          "ruby agent_service.rb\n " +
          "done",
        true)
        `chmod +x /tmp/toaster.agent.loop.sh`
        cmd = "cd #{dir} && screen -m -d bash /tmp/toaster.agent.loop.sh"
        puts "INFO: Starting test agent in the background (using screen), using port #{@@port}."
        `#{cmd}`
      else
        puts "INFO: Another test agent instance is already running on this host."
      end
    end

    def self.do_start_agent()
      require 'toaster/util/web_server'
      $agent_port = @@port
      require "toaster/agent/agent_service"
    end

    def to_s
      return "<TestAgent@#{@host}>"
    end

  end
end

if ARGV[0] == "run_test_agent"
  Toaster::TestAgent.do_start_agent()
  sleep 1
  puts "Press <ENTER> to terminate"
  $stdin.gets
end
