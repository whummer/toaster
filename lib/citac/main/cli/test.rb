require 'thor'
require_relative '../ioc'
require_relative '../core/test_case_generator'
require_relative '../tasks/testing'
require_relative '../../commons/utils/colorize'
require_relative '../../commons/utils/range'

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

        #TODO define coverage parameters
        desc 'gen <spec> <os>', 'Generates a test suite according to the given coverage parameters.'
        def gen(spec_id, os)
          spec, os = load_spec spec_id, os

          #TODO remove once coverage parameters are defined
          suites = @repo.test_suites spec, os
          raise 'Currently only base test suite generation is supported.' unless suites.empty?

          dg = @spec_service.dependency_graph spec, os

          tcg = Citac::Core::TestCaseGenerator.new dg
          test_suite = tcg.generate_test_suite

          @repo.save_test_suite spec, os, test_suite
        end

        desc 'suites <spec> <os>', 'Lists the test suites for the given configuration specification.'
        def suites(spec_id, os)
          spec, os = load_spec spec_id, os

          suites = @repo.test_suites(spec, os)
          suites.each do |test_suite|
            puts "#{test_suite.id}\t#{test_suite.name}"
          end

          if suites.empty?
            puts 'No test suites.'
          end
        end

        option :steps, :type => :boolean, :aliases => :s, :desc => 'include detailed test steps'
        desc 'cases <spec> <os> <suite>', 'Prints the test cases of the given test suite of the configuration specification.'
        def cases(spec_id, os, suite_id)
          _, _, test_suite = load_test_suite spec_id, os, suite_id

          case_count = 0
          step_count = 0
          test_suite.test_cases.each do |test_case|
            case_count += 1
            step_count += test_case.steps.size

            if options[:steps]
              puts "#{case_count}\t#{test_case}"
            else
              puts "#{case_count}\t#{test_case.name}"
            end
          end

          puts
          puts "#{test_suite.test_cases.size} test cases (#{step_count} steps)."
        end

        option :passthrough, :aliases => :p, :desc => 'Enables output passthrough of test steps'
        desc 'exec <spec> <os> <suite> [<case>]', 'Executes the specified test case for the given configuration specification.'
        def exec(spec_id, os, suite_id, case_range = nil)
          spec, os, test_suite = load_test_suite spec_id, os, suite_id
          case_ids = parse_case_range test_suite, case_range

          results = Hash.new
          case_ids.each do |case_id|
            test_case = test_suite.test_case case_id

            msg = "# Test case #{test_case.id}: #{test_case.name}... #"
            puts ''.ljust msg.size, '='
            puts msg
            puts ''.ljust msg.size, '='
            puts

            task = Citac::Main::Tasks::TestTask.new @repo, spec, test_suite, test_case
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
              test_case = test_suite.test_case case_id
              test_case_result = results[case_id]
              status = test_case_result.colored_result

              puts "#{status}  Test case #{case_id}: #{test_case.name}"
            end
          end
        end

        desc 'results <spec> <os> <suite> [<cases>]', 'Prints test case results.'
        def results(spec_id, os, suite_id, case_range = nil)
          spec, os, test_suite = load_test_suite spec_id, os, suite_id
          suite_results = @repo.test_suite_results spec, os, test_suite

          puts "Case ID\tResult\tSuccess\tFailure\tAborted"

          case_ids = parse_case_range test_suite, case_range
          case_ids.each do |case_id|
            test_case = test_suite.test_case case_id
            result = suite_results.overall_case_result(test_case)

            results = suite_results.test_case_results[case_id] || []
            success_count = results.select{|r| r == :success}.size
            failure_count = results.select{|r| r == :failure}.size
            aborted_count = results.select{|r| r == :aborted}.size

            result = result.to_s.green if result == :success
            result = result.to_s.red if result == :failure

            puts "#{case_id}\t#{result}\t#{success_count}\t#{failure_count}\t#{aborted_count}"
          end
        end

        no_commands do
          def load_spec(spec_id, os)
            spec = @repo.get spec_id
            os = Citac::Model::OperatingSystem.parse os
            os = @spec_service.get_specific_operating_system spec, os

            return spec, os
          end

          def load_test_suite(spec_id, os, suite_id)
            spec, os = load_spec spec_id, os
            test_suite = @repo.test_suite spec, os, suite_id

            return spec, os, test_suite
          end

          def parse_case_range(test_suite, case_range)
            Citac::Utils::RangeParser.parse case_range, 1, test_suite.test_cases.size
          end
        end
      end
    end
  end
end