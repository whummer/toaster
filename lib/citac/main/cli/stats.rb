require 'set'
require 'thor'
require_relative '../../commons/model'
require_relative '../../commons/utils/mathex'
require_relative '../ioc'
require_relative '../core/stg'
require_relative '../core/stg_builder'

module Citac
  module Main
    module CLI
      class Stats < Thor
        def initialize(*args)
          super

          @repo = ServiceLocator.specification_repository
          @spec_service = ServiceLocator.specification_service
        end

        desc 'rc', 'Prints the resource counts of all configuration specifications.'
        def rc
          @repo.each_spec do |spec_name|
            spec = @repo.get spec_name
            os = spec.operating_systems.find {|os| @repo.has_dependency_graph? spec, os}
            next unless os

            dg = @repo.dependency_graph spec, os
            print "#{spec_name};#{dg.nodes.size};"
            $stdout.flush

            stg = Citac::Core::DependencyGraph.new(dg).to_stg
            print "#{stg.nodes.size};"
            $stdout.flush

            path_count = stg.dag_path_count
            puts path_count.to_s
          end
        end

        desc 'stgcomp', 'Prints the number of nodes in the min and full STG.'
        def stgcomp
          puts 'name;resource count;min stg size;min stg path count;full stg size;full stg path count'
          @repo.each_spec do |spec_name|
            spec = @repo.get spec_name
            os = spec.operating_systems.find {|os| @repo.has_dependency_graph? spec, os}
            next unless os

            dg = @repo.dependency_graph spec, os
            print "#{spec_name};#{dg.nodes.size};"
            $stdout.flush

            dg = Citac::Core::DependencyGraph.new(dg)

            stg_builder = Citac::Main::Core::StgBuilder.new dg
            stg_builder.add_minimal_states
            min_stg = stg_builder.stg

            print "#{min_stg.nodes.size};"
            $stdout.flush

            min_stg_path_count = min_stg.dag_path_count
            print "#{min_stg_path_count};"
            $stdout.flush

            full_stg = dg.to_stg
            print "#{full_stg.nodes.size};"
            $stdout.flush

            full_stg_path_count = full_stg.dag_path_count
            puts full_stg_path_count.to_s
          end
        end

        desc 'td', 'Prints the type distribution of all configuration specifications.'
        def td
          counts = Hash.new 0

          @repo.each_spec do |spec_name|
            spec = @repo.get spec_name
            os = spec.operating_systems.find {|os| @repo.has_dependency_graph? spec, os}
            next unless os

            dg = @repo.dependency_graph spec, os
            dg.nodes.each do |node|
              type = resource_to_type node.label
              counts[type] += 1
            end
          end

          counts.each do |type, count|
            puts "#{type};#{count}"
          end
        end

        desc 'ts', 'Prints test suite statistics for all configuration specifications.'
        def ts
          puts 'name;resource count;base execs;base asserts;stg execs;stg asserts'
          @repo.each_spec do |spec_name|
            spec = @repo.get spec_name
            os = spec.operating_systems.find {|os| @repo.has_dependency_graph? spec, os}
            next unless os

            dg = @repo.dependency_graph spec, os

            suites = @repo.test_suites spec, os
            base = suites.find {|s| s.name =~ /base/}
            stg = suites.find {|s| s.name =~ /stg/}

            if base
              base_execs, base_asserts = suite_step_counts base
            else
              base_execs = 'n/a'
              base_asserts = 'n/a'
            end

            if stg
              stg_execs, stg_asserts = suite_step_counts stg
            else
              stg_execs = 'n/a'
              stg_asserts = 'n/a'
            end

            puts "#{spec_name};#{dg.nodes.size};#{base_execs};#{base_asserts};#{stg_execs};#{stg_asserts}"
          end
        end

        desc 'stg', 'Prints stg test suite statistics for all configuration specifications.'
        def stg
          puts 'name;resource count;coverage;edge limit;expansion;all edges;execs;asserts'
          @repo.each_spec do |spec_name|
            spec = @repo.get spec_name
            os = spec.operating_systems.find {|os| @repo.has_dependency_graph? spec, os}
            next unless os

            dg = @repo.dependency_graph spec, os

            suites = @repo.test_suites spec, os
            suites.each do |suite|
              next unless suite.type == :stg

              execs, asserts = suite_step_counts suite
              puts "#{spec_name};#{dg.nodes.size};#{suite.stg_coverage};#{suite.stg_edgelimit};#{suite.stg_expansion};#{suite.stg_alledges};#{execs};#{asserts}"
              $stdout.flush
            end
          end
        end

        desc 'filetests', 'Prints statistics for file related test cases.'
        def filetests
          puts 'name;resource count;base total;base idempotence;base preservation;stg_total;stg idempotence;stg preservation'
          @repo.each_spec do |spec_name|
            spec = @repo.get spec_name
            os = spec.operating_systems.find {|os| @repo.has_dependency_graph? spec, os}
            next unless os

            dg = @repo.dependency_graph spec, os

            suites = @repo.test_suites spec, os
            base = suites.find {|s| s.name =~ /base/}
            stg = suites.find {|s| s.name =~ /stg/}

            if base
              base_total, base_idempotence, base_convergence = suite_file_tests base
            else
              base_total = 'n/a'
              base_idempotence = 'n/a'
              base_convergence = 'n/a'
            end

            if stg
              stg_total, stg_idempotence, stg_convergence = suite_file_tests stg
            else
              stg_total = 'n/a'
              stg_idempotence = 'n/a'
              stg_convergence = 'n/a'
            end

            puts "#{spec_name};#{dg.nodes.size};#{base_total};#{base_idempotence};#{base_convergence};#{stg_total};#{stg_idempotence};#{stg_convergence}"
          end
        end

        desc 'perf', 'Prints the average performance for each step and resource type.'
        def perf(summary_path = 'step-summary.csv', detail_path = 'step-details.csv')
          types = Set.new
          exec_times = Hash.new {|h,k| h[k] = []}
          assert_times = Hash.new {|h,k| h[k] = []}

          File.open detail_path, 'w' do |detail|
            detail.puts 'resource type;step type;execution time'

            @repo.each_spec do |spec_name|
              spec = @repo.get spec_name
              spec.operating_systems.each do |os|
                next unless @repo.has_dependency_graph? spec, os
                puts "Analyzing #{spec_name} on #{os}..."

                suites = @repo.test_suites spec, os
                suites.each do |suite|
                  suite.test_cases.each do |test_case|
                    test_case_results = @repo.test_case_results spec, os, suite, test_case
                    test_case_results.each do |case_result|
                      case_result.step_results.each do |step_result|
                        next unless step_result.execution_time

                        type = resource_to_type step_result.step.resource
                        types << type

                        if step_result.step.type == :exec
                          detail.puts "#{type};exec;#{step_result.execution_time}"
                          exec_times[type] << step_result.execution_time
                        elsif step_result.step.type == :assert
                          detail.puts "#{type};assert;#{step_result.execution_time}"
                          assert_times[type] << step_result.execution_time
                        else
                          raise "Unknown test step type: #{step_result.step.type}"
                        end
                      end
                    end
                  end
                end
              end
            end
          end

          File.open summary_path, 'w' do |summary|
            summary.puts 'type;exec steps;average exec time;assert steps;average assert time'
            types.each do |type|
              avg_exec, avg_assert = -1, -1
              avg_exec = exec_times[type].reduce(0.0, :+) / exec_times[type].size unless exec_times[type].empty?
              avg_assert = assert_times[type].reduce(0.0, :+) / assert_times[type].size unless assert_times[type].empty?

              summary.puts "#{type};#{exec_times[type].size};#{avg_exec};#{assert_times[type].size};#{avg_assert}"
            end
          end
        end


        desc 'slowaptkey', 'Prints slow apt_key assertions.'
        def slowaptkey
          @repo.each_spec do |spec_name|
            spec = @repo.get spec_name
            spec.operating_systems.each do |os|
              next unless @repo.has_dependency_graph? spec, os
              puts "Analyzing #{spec_name} on #{os}..."

              suites = @repo.test_suites spec, os
              suites.each do |suite|
                suite.test_cases.each do |test_case|
                  test_case_results = @repo.test_case_results spec, os, suite, test_case
                  test_case_results.each do |case_result|
                    case_result.step_results.each_with_index do |step_result, index|
                      next unless step_result.step.type == :assert
                      next unless (step_result.execution_time || 0) > 10

                      type = resource_to_type step_result.step.resource
                      next unless type == 'apt_key'

                      puts "#{spec_name};#{os};#{suite.id};#{test_case.id};#{index + 1}"
                    end
                  end
                end
              end
            end
          end
        end

        desc 'results', 'Prints the test suite results.'
        def results
          puts 'name;os;type;result'
          $stdout.flush

          @repo.each_spec do |spec_name|
            spec = @repo.get spec_name
            oss = spec.operating_systems.select {|os| @repo.has_dependency_graph? spec, os}
            oss.each do |os|
              suites = @repo.test_suites spec, os
              suites.each do |suite|
                suite_result = @repo.test_suite_results spec, os, suite
                r = suite_result.overall_suite_result

                puts "#{spec_name};#{os};#{suite.type};#{r}"
                $stdout.flush
              end
            end
          end
        end

        no_commands do
          def resource_to_type(resource)
            index = resource.index('[') - 1
            resource.downcase[0..index]
          end

          def suite_step_counts(suite)
            execs = 0
            asserts = 0

            suite.test_cases.each do |test_case|
              test_case.steps.each do |test_step|
                if test_step.type == :exec
                  execs += 1
                elsif test_step.type == :assert
                  asserts += 1
                else
                  raise "Unknown test step type: #{test_step.type}"
                end
              end
            end

            return execs, asserts
          end

          def suite_file_tests(suite)
            total = 0
            idempotence = 0
            preservation = 0

            suite.test_cases.each do |test_case|
              test_case.steps.each do |test_step|
                next unless test_step.type == :assert
                total += 1

                if test_step.property.type == :idempotence
                  type = resource_to_type test_step.property.resources[0]
                  idempotence += 1 if type == 'file'
                elsif test_step.property.type == :preservation
                  type1 = resource_to_type test_step.property.resources[0]
                  type2 = resource_to_type test_step.property.resources[1]

                  preservation += 1 if type1 == 'file' && type2 == 'file'
                else
                  raise "Unknown property type: #{test_step.property.type}"
                end
              end
            end

            return total, idempotence, preservation
          end
        end
      end
    end
  end
end