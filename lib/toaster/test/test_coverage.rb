

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/test/test_coverage_goal"

include Toaster

module Toaster

  class TestCoverage

    attr_accessor :test_suite, :state_graph

    def initialize(test_suite, state_graph = nil)
      @state_graph = state_graph
      @test_suite = test_suite
      if !state_graph
        automation = test_suite.automation
        @state_graph = StateTransitionGraph.build_graph_for_test_suite(@test_suite)
      end 
    end

    def cvg_states()
      return covered_states().size.to_f / @state_graph.nodes().size.to_f
    end

    def test_executed?(test_case)
      executed_tests = @test_suite.test_cases
      skip_task_uuids = test_case.skip_task_uuids
      repeat_task_uuids = test_case.repeat_task_uuids
      attrs = test_case.test_attributes

      executed_tests.each do |t|
        # check skip_task_uuids
        if t.skip_task_uuids.eql?(skip_task_uuids)
          # check repeat_task_uuids
          if t.repeat_task_uuids.eql?(repeat_task_uuids)
            # check automation run attributes
            if t.automation_run
              attrs1 = t.automation_run.run_attributes
              if attrs1.eql?(attrs)
                puts "INFO: test case already executed: skip_tasks: #{skip_task_uuids}, repeat_tasks: #{repeat_task_uuids}, attributes: #{attrs}"
                return true
              end
            end
          end
        end
      end
      return false
    end

    def covered_transitions()
      result = Set.new
      executed_tests = @test_suite.test_cases
      @state_graph.edges().each do |e|
        tests = tests_covering_transition(e, true)
        if !tests.empty?()
          result << e
        end
      end
      return result
    end

    def covered_states()
      result = Set.new
      executed_tests = @test_suite.test_cases
      @state_graph.nodes().each do |n|
        tests = tests_covering_state(n, true)
        if !tests.empty?()
          result << n
        end
      end
      return result
    end

    def tests_covering_state(state_node, return_after_first_result=false)
      result = Set.new
      executed_tests = @test_suite.test_cases
      pre_task = state_node.preceding_task
      suc_task = state_node.succeeding_task

      executed_tests.each do |test|
        # check if the post-state of the pre-task of the 
        # given state matches for this test execution
        if pre_task
          exec = test.task_execution(pre_task.uuid)
          if exec
            poststate = exec.state_after()
            if state_node.subset_of?(poststate, ["__task_num__"])
              result << test
              return result if return_after_first_result
              next
            end
          end
        end
        # check if the pre-state of the post-task of the 
        # given state matches for this test execution
        if suc_task
          exec = test.task_execution(suc_task.uuid)
          if exec
            prestate = exec.state_before
            if state_node.subset_of?(prestate, ["__task_num__"])
              result << test
              return result if return_after_first_result
            end
          end
        end
      end

      return result
    end

    def tests_covering_transition(transition_edge, return_after_first_result=false)
      result = Set.new
      task = transition_edge.represented_task
      executed_tests = @test_suite.test_cases
      executed_tests.each do |test|
        # check if task has been executed by test case
        if !test.executed_task_uuids().include?(task.uuid)
          next
        end
        exec = test.task_execution(task.uuid)

        # check if the task parameters match the transition condition
        params = exec.get_used_parameters()
        if !transition_edge.matches_parameters?(params)
          next
        end

        # check if the pre-state and post-state match
        prestate = exec.state_before()
        poststate = exec.state_after()
        if !transition_edge.matches_states?(prestate, poststate)
          next
        end

        # all tests passed, add to result
        result << test
        return result if return_after_first_result
      end
    end

  end
end
