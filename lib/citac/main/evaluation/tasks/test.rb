require_relative '../../../commons/utils/exec'
require_relative 'base'

module Citac
  module Main
    module Evaluation
      class TestTask < EvaluationTask
        def initialize(task_description, spec_repository, task_repository, environment_manager, agent_name, type)
          super task_description, spec_repository, task_repository, environment_manager, agent_name
          @type = type
        end

        def get_suite(spec, operating_system)
          spec_repository.test_suites(spec, operating_system).
              select{|s| s.name.include? @type.to_s}.
              sort_by{|s| s.id}.
              first
        rescue
          false
        end

        def unknown_test_case_exists?(suite, suite_result)
          suite.test_cases.any? { |tc| suite_result.overall_case_result(tc) == :unknown }
        end

        def get_pending_test_case(suite, suite_result)
          suite.test_cases.find{ |tc| suite_result.overall_case_result(tc) == :unknown &&
              (suite_result.test_case_results[tc.id] || []).size < 5} # skip test case after 5 aborts
        end

        def fulfilled?(spec, operating_system)
          suite = get_suite spec, operating_system
          suite_result = spec_repository.test_suite_results spec, operating_system, suite

          get_pending_test_case(suite, suite_result).nil? && !unknown_test_case_exists?(suite, suite_result)
        rescue
          return false
        end

        def execute_os(spec, operating_system)
          suite = get_suite spec, operating_system
          suite_result = spec_repository.test_suite_results spec, operating_system, suite

          pending_test_case = get_pending_test_case suite, suite_result
          return (unknown_test_case_exists?(suite, suite_result) ? :failure : :success_completed) unless pending_test_case

          args = ['test', 'exec', spec.id, operating_system, suite.id, pending_test_case.id]
          result = Citac::Utils::Exec.run 'citac', :args => args, :output => :passthrough, :raise_on_failure => false
          result.success? ? :success_partial : :failure
        end
      end
    end
  end
end