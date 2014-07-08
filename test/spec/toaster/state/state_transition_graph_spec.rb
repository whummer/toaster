
#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#
require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

require 'toaster/util/config'
require 'toaster/state/state_transition_graph'
require 'toaster/test/test_suite'
require 'toaster/test/test_coverage'
require 'toaster/model/automation'

include Toaster

# This test can only be executed if the cookbook "apache2" from opscode has been
# tested using the Toaster testing framework and the database contains the test data.
# If the data are missing, the test outputs a warning message.

if $run_tests_involving_db
  describe StateTransitionGraph, "::build_graph_for_automation" do
  
    # database connection settings
    DB.DEFAULT_HOST = Toaster::Config.get('db.host')
    DB.DEFAULT_PORT = 27017
    DB.DEFAULT_DB = "toaster"
  
    automation_name = "node[apache2]"
    test_coverage = nil
    automation = nil
    test_suite = nil
    begin
      begin
        automation = Automation.find("name" => automation_name)[0]
        raise "No automation found with name '#{automation_name}'" if !automation
        test_suite = TestSuite.find("automation_id" => automation.id)[0]
      rescue => ex1
        puts "SPEC_WARN: Could not load test data from DB: #{ex1}"
      end
    rescue => ex
      puts ex
      puts "SPEC_WARN: Could not connect to database at #{DB.DEFAULT_HOST}:#{DB.DEFAULT_PORT}. Please check test settings."
    end

    it "correctly builds state graph for automation" do
      if automation
        graph = StateTransitionGraph.build_graph_for_automation(automation)
        graph.nodes.size.should be > 0
        graph.edges.size.should be > 0
        puts "\nSPEC_INFO: Number of nodes/edges in state transition graph: #{graph.nodes.size}/#{graph.edges.size}"

        test_coverage = TestCoverage.new(test_suite, graph)
        states = test_coverage.covered_states()
        puts "SPEC_INFO: covered states: #{states.size} of #{graph.nodes.size}"
        states.size.should be > 0
        transitions = test_coverage.covered_transitions()
        puts "SPEC_INFO: covered transitions: #{transitions.size} of #{graph.edges.size}"
        transitions.size.should be > 0
      end
    end
  
  end
end
