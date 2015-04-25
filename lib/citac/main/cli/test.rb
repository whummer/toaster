require 'thor'
require_relative '../ioc'
require_relative '../core/test_case_generator'
require_relative '../tasks/testing'
require_relative '../../commons/utils/colorize'

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

        option :steps, :type => :boolean, :aliases => :s, :desc => 'include detailed test steps'
        desc 'list <spec> <os>', 'Prints possible test cases for the given configuration specification.'
        def list(spec_id, os)
          spec, os, test_suite = load_test_suite spec_id, os

          case_count = 0
          step_count = 0
          test_suite.each do |test_case|
            case_count += 1
            step_count += test_case.steps.size

            if options[:steps]
              puts "#{case_count}\t#{test_case}"
            else
              puts "#{case_count}\t#{test_case.name}"
            end
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

        option :passthrough, :aliases => :p, :desc => 'Enables output passthrough of test steps'
        desc 'exec <spec> <os> [<case>]', 'Executes the specified test case for the given configuration specification.'
        def exec(spec_id, os, case_range = nil)
          spec, os, test_suite = load_test_suite spec_id, os
          case_ids = parse_case_range test_suite, case_range

          results = Hash.new
          case_ids.each do |case_id|
            test_case = test_suite[case_id - 1]

            msg = "# Test case #{test_case.id}: #{test_case.name}... #"
            puts ''.ljust msg.size, '='
            puts msg
            puts ''.ljust msg.size, '='
            puts

            task = Citac::Main::Tasks::TestTask.new @repo, spec, test_case
            task.passthrough = options[:passthrough]
            test_case_result = @exec_mgr.execute task, os, :output => :passthrough

            puts if case_ids.size > 1

            results[case_id] = test_case_result
          end

          if case_ids.size > 1
            puts '==================='
            puts '# Overall Summary #'
            puts '==================='
            puts
            case_ids.each do |case_id|
              test_case = test_suite[case_id - 1]
              test_case_result = results[case_id]
              status = test_case_result.success? ? 'SUCCESS'.green : 'FAILURE'.red

              puts "#{status}  Test case #{case_id}: #{test_case.name}"
            end
          end
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

          def parse_case_range(test_suite, case_range)
            return (1..test_suite.size).to_a unless case_range || case_range == '*'
            if case_range.include? '-'
              pieces = case_range.to_s.split '-', 2
              min = [1, pieces.first.to_i].max
              max = [test_suite.size, pieces.last.to_i].min

              (min..max).to_a
            else
              [case_range.to_i]
            end
          end
        end
      end
    end
  end
end