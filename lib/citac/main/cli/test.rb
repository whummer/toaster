require 'thor'
require_relative '../ioc'
require_relative '../core/test_case_generator'
require_relative '../tasks/testing'

module Citac
  module Main
    module CLI
      class Test < Thor
        def initialize(*args)
          super

          @repo = ServiceLocator.specification_repository
          @spec_service = ServiceLocator.specification_service
          @exec_mgr = ServiceLocator.execution_manager
        end

        desc 'list <spec> <os>', 'Prints possible test cases for the given configuration specification.'
        def list(spec_id, os)
          spec, os, test_suite = load_test_suite spec_id, os

          case_count = 0
          step_count = 0
          test_suite.each do |test_case|
            case_count += 1
            step_count += test_case.steps.size

            puts "#{case_count}\t#{test_case}"
          end

          puts
          puts "#{test_suite.size} test cases (#{step_count} steps)."
        end

        desc 'get <spec> <os> <case>', 'Gets the specified test case for the given configuration specification.'
        def get(spec_id, os, case_id)
          spec, os, test_suite = load_test_suite spec_id, os

          test_case = test_suite[case_id.to_i - 1]
          puts test_case.to_yaml
        end

        option :print, :aliases => :p
        desc 'exec <spec> <os> <case>', 'Executes the specified test case for the given configuration specification.'
        def exec(spec_id, os, case_id)
          spec, os, test_suite = load_test_suite spec_id, os
          test_case = test_suite[case_id.to_i - 1]

          task = Citac::Main::Tasks::TestTask.new @repo, spec, test_case
          @exec_mgr.execute task, os, :output => :passthrough
        end

        no_commands do
          def load_test_suite(spec_id, os)
            spec = @repo.get spec_id
            os = Citac::Model::OperatingSystem.parse os
            os = @spec_service.get_specific_operating_system spec, os

            dg = @spec_service.dependency_graph spec, os
            tcg = Citac::Core::TestCaseGenerator.new dg
            test_suite = tcg.generate_test_suite

            return spec, os, test_suite
          end
        end
      end
    end
  end
end