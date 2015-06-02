require 'thor'
require_relative '../ioc'
require_relative '../core/test_case_generators/simple'
require_relative '../core/test_case_generators/stg_based'
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
          @env_mgr = ServiceLocator.environment_manager
        end

        option :type, :aliases => :t, :default => 'stg', :desc => 'test case generation algorithm, either "base" or "stg"'
        option :preview, :aliases => :p, :type => :boolean, :desc => 'preview mode'
        option :printasserts, :aliases => :a, :type => :boolean, :desc => 'prints an assert overview'
        option :expand, :aliases => :x, :type => :numeric, :default => 0, :desc => 'number of STG expansion steps'
        option :alledges, :aliases => :e, :type => :boolean, :desc => 'add missing edges'
        option :coverage, :aliases => :c, :default => 'edge', :desc => 'coverage type'
        option :edgelimit, :aliases => :l, :type => :numeric, :default => 3, :desc => 'max number of edge visits (for asserts)'
        desc 'gen <spec> <os>', 'Generates a test suite according to the given coverage parameters.'
        def gen(spec_id, os)
          spec, os = load_spec spec_id, os
          dg = @spec_service.dependency_graph spec, os

          case options[:type]
            when 'base'
              generator = Citac::Main::Core::TestCaseGenerators::SimpleTestCaseGenerator.new dg
            when 'stg'
              generator = Citac::Main::Core::TestCaseGenerators::StgBasedTestCaseGenerator.new dg
              generator.expansion = options[:expand]
              generator.all_edges = options[:alledges]
              generator.coverage = options[:coverage] == 'path' ? :path : :edge
              generator.edge_limit = options[:edgelimit]
            else
              raise "Unknown test case generator: #{options[:type]}"
          end

          test_suite = generator.generate_test_suite

          print_test_suite test_suite
          print_asserts dg, test_suite if options[:printasserts]

          puts
          if options[:preview]
            puts 'Discarding test suite because running in preview mode.'
          else
            @repo.save_test_suite spec, os, test_suite
            puts "Saved test suite with ID #{test_suite.id}"
          end
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

        desc 'cases <spec> <os> <suite>', 'Prints the test cases of the given test suite of the configuration specification.'
        def cases(spec_id, os, suite_id)
          _, _, test_suite = load_test_suite spec_id, os, suite_id
          print_test_suite test_suite
        end

        desc 'asserts <spec> <os> <suite>', 'Prints an overview of the asserts of the given test suite of the configuration specification.'
        def asserts(spec_id, os, suite_id)
          spec, os, test_suite = load_test_suite spec_id, os, suite_id
          dg = @spec_service.dependency_graph spec, os
          print_asserts dg, test_suite
        end

        option :passthrough, :aliases => :p, :desc => 'Enables output passthrough of test steps'
        desc 'exec <spec> <os> <suite> [<case>]', 'Executes the specified test case for the given configuration specification.'
        def exec(spec_id, os, suite_id, case_range = nil)
          spec, os, test_suite = load_test_suite spec_id, os, suite_id
          case_ids = parse_case_range test_suite, case_range

          results = Hash.new
          case_ids.each do |case_id|
            test_case = test_suite.test_case case_id

            msg = "# #{test_case.name} #"
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

        option :successes, :type => :boolean, :aliases => :s, :desc => 'Prints successful test cases.'
        option :failures, :type => :boolean, :aliases => :f, :desc => 'Prints failed test cases.'
        option :unknowns, :type => :boolean, :aliases => :u, :desc => 'Prints unknown test cases.'
        option :summary, :type => :boolean, :default => true, :desc => 'Printa a status summary at the end.'
        desc 'results <spec> <os> <suite> [<cases>]', 'Prints test case results.'
        def results(spec_id, os, suite_id, case_range = nil)
          filter = options[:successes] || options[:failures] || options[:unknowns]
          printed_results = []
          printed_results << :success if options[:successes] || !filter
          printed_results << :failure if options[:failures] || !filter
          printed_results << :unknown if options[:unknowns] || !filter

          spec, os, test_suite = load_test_suite spec_id, os, suite_id
          suite_results = @repo.test_suite_results spec, os, test_suite

          result_summary = Hash.new {|h, k| h[k] = 0}

          puts "Case ID\tResult\tSuccess\tFailure\tAborted"

          case_ids = parse_case_range test_suite, case_range
          case_ids.each do |case_id|
            test_case = test_suite.test_case case_id
            result = suite_results.overall_case_result(test_case)
            result_summary[result] += 1

            next unless printed_results.include? result

            results = suite_results.test_case_results[case_id] || []
            success_count = results.select{|r| r == :success}.size
            failure_count = results.select{|r| r == :failure}.size
            aborted_count = results.select{|r| r == :aborted}.size

            result = result.to_s.green if result == :success
            result = result.to_s.red if result == :failure

            puts "#{case_id}\t#{result}\t#{success_count}\t#{failure_count}\t#{aborted_count}"
          end

          if options[:summary]
            puts
            puts "Successes: #{result_summary[:success]}"
            puts "Failures:  #{result_summary[:failure]}"
            puts "Unknowns:  #{result_summary[:unknown]}"
          end
        end

        desc 'clearresults <spec> [<os> [<suite> [<cases>]]]', 'Deletes test case results.'
        def clearresults(spec_id, os = nil, suite_id = nil, case_range = nil)
          spec = @repo.get spec_id

          os = Citac::Model::OperatingSystem.parse os if os
          if os
            oss = os.specific? ? [os] : @env_mgr.operating_systems(spec.type).select{|o| o.matches? os}
          else
            oss = @env_mgr.operating_systems spec.type
          end

          oss.each do |os|
            puts "Clearing results for #{os}..." if $verbose
            test_suites = suite_id ? [@repo.test_suite(spec, os, suite_id)] : @repo.test_suites(spec, os)
            test_suites.each do |test_suite|
              puts "  Processing test suite '#{test_suite}'..." if $verbose
              range = parse_case_range test_suite, case_range
              range.each do |case_id|
                test_case = test_suite.test_case case_id
                @repo.clear_test_case_results spec, os, test_suite, test_case
              end
            end
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
            raise "Test suite with ID #{suite_id} not found for #{spec} on #{os}." unless test_suite

            return spec, os, test_suite
          end

          def parse_case_range(test_suite, case_range)
            Citac::Utils::RangeParser.parse case_range, 1, test_suite.test_cases.size
          end

          def print_test_suite(test_suite)
            step_count_by_type = Hash.new 0
            step_count = 0
            test_suite.test_cases.each do |test_case|
              test_case.steps.each do |step|
                step_count_by_type[step.type] += 1
                step_count += 1
              end

              puts test_case
            end

            puts
            puts "#{test_suite.test_cases.size} test cases (#{step_count} steps: #{step_count_by_type.map{|k, v| "#{v} #{k}s"}.join(', ')})"
          end

          def print_asserts(dg, test_suite)
            properties = Hash.new 0
            test_suite.test_cases.each do |test_case|
              test_case.asserts.each do |assert_step|
                properties[assert_step.property] += 1
              end
            end

            properties.sort_by { |property, count| [-count, property.to_s] }.each do |property, count|
              puts "#{count}\t#{property}"
            end

            puts
            missing_properties = dg.required_properties.reject { |p| properties.include?(p) && properties[p] > 0 }
            if missing_properties.empty?
              puts 'All required properties are tested.'
            else
              puts 'The following required properties are not tested:'
              missing_properties.each do |missing_property|
                puts " - #{missing_property}"
              end
            end
          end
        end
      end
    end
  end
end