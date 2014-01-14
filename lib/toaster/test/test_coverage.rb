

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

include Toaster

module Toaster

  class CombinationCoverage
    SKIP_N = 1
    SKIP_N_SUCCESSIVE = 2
    COMBINE_N = 3
    COMBINE_N_SUCCESSIVE = 4
  end

  class StateGraphCoverage
    STATES = 1
    TRANSITIONS = 2
    TRANSITION_PAIRS = 3
    FULL_SEQUENCE = 4
  end

  class TestCoverageGoal
    attr_accessor :idempotence, :combinations, :repeat_N, :optimize_for_rendering, :graph, :only_connect_to_start
    def initialize(idempotence_N=0, 
          skip_N=[], skip_N_successive=[], 
          combine_N=[], combine_N_successive=[], 
          graph_coverage = StateGraphCoverage::STATES,
          only_connect_to_start = true
      )
      @idempotence = idempotence_N
      @combinations = {
        CombinationCoverage::SKIP_N => skip_N ? skip_N : [],
        CombinationCoverage::SKIP_N_SUCCESSIVE => skip_N_successive ? skip_N_successive : [],
        CombinationCoverage::COMBINE_N => combine_N ? combine_N : [],
        CombinationCoverage::COMBINE_N_SUCCESSIVE => combine_N_successive ? combine_N_successive : []
      }
      @graph = graph_coverage ? graph_coverage : StateGraphCoverage::STATES
      @only_connect_to_start = only_connect_to_start
      @repeat_N = 1
      @optimize_for_rendering = false
    end
    def set_only_connect_to_start(do_only_connect_to_start)
      @only_connect_to_start = do_only_connect_to_start
      return self
    end
    def set_repeat_N(repeat_N)
      @repeat_N = repeat_N
      return self
    end
    def to_hash(exclude_fields = [], additional_fields = {}, recursion_fields = [])
      return {
        "idemN" => @idempotence,
        "comb" => {
          "c#{CombinationCoverage::SKIP_N}" => @combinations[CombinationCoverage::SKIP_N],
          "c#{CombinationCoverage::SKIP_N_SUCCESSIVE}" => @combinations[CombinationCoverage::SKIP_N_SUCCESSIVE],
          "c#{CombinationCoverage::COMBINE_N}" => @combinations[CombinationCoverage::COMBINE_N],
          "c#{CombinationCoverage::COMBINE_N_SUCCESSIVE}" => @combinations[CombinationCoverage::COMBINE_N_SUCCESSIVE]
        },
        "graph" => @graph,
        "only_connect_to_start" => @only_connect_to_start
      }
    end
    def self.from_hash(hash)
      return TestCoverageGoal.new(
        hash["idemN"], 
        hash["comb"]["c#{CombinationCoverage::SKIP_N}"],
        hash["comb"]["c#{CombinationCoverage::SKIP_N_SUCCESSIVE}"],
        hash["comb"]["c#{CombinationCoverage::COMBINE_N}"],
        hash["comb"]["c#{CombinationCoverage::COMBINE_N_SUCCESSIVE}"],
        hash["graph"],
        hash["only_connect_to_start"]
      )
    end
  end


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
      attrs = test_case.attributes

      executed_tests.each do |t|
        # check skip_task_uuids
        if t.skip_task_uuids.eql?(skip_task_uuids)
          # check repeat_task_uuids
          if t.repeat_task_uuids.eql?(repeat_task_uuids)
            # check automation run attributes
            if t.automation_run
              attrs1 = t.automation_run.attributes
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
          exec = test.task_execution(pre_task.uuid, true)
          poststate = exec.state_after()
          if state_node.subset_of?(poststate, ["__task_num__"])
            result << test
            return result if return_after_first_result
            next
          end
        end
        # check if the pre-state of the post-task of the 
        # given state matches for this test execution
        if suc_task
          exec = test.task_execution(suc_task.uuid, true)
          prestate = exec.state_before()
          if state_node.subset_of?(prestate, ["__task_num__"])
            result << test
            return result if return_after_first_result
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
        exec = test.task_execution(task.uuid, true)

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
