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
      class Export < Thor
        def initialize(*args)
          super

          @repo = ServiceLocator.specification_repository
          @spec_service = ServiceLocator.specification_service
        end

        desc 'all', 'Exports all configuration specifications and generates a summary.'
        def all(out_dir = '.')
          @repo.each_spec do |spec|
            spec spec, out_dir
          end
          list out_dir
        end

        desc 'spec', 'Exports a configuration specification.'
        def spec(spec_id, out_dir = '.')
          spec = @repo.get spec_id
          @out_dir = File.join out_dir, spec.id
          FileUtils.rm_rf @out_dir

          generate_spec_details spec
        end

        desc 'list', 'Generates a summay of all configuration specifications.'
        def list(out_dir = '.')
          @out_dir = out_dir
          result = []

          Dir.foreach out_dir do |spec_dir|
            next if spec_dir == '.' || spec_dir == '..'

            path = File.join out_dir, spec_dir
            next unless File.directory? path

            puts "Processing #{spec_dir}..."

            json = IO.read File.join(path, 'spec.json'), :encoding => 'UTF-8'
            data = JSON.load json

            data['operatingSystems'].each do |os|
              result << {
                  'id' => data['id'],
                  'operatingSystem' => os,
                  'resourceCount' => data['resourceCounts'][os],
                  'detectedIssues' => data['detectedIssues'][os].size
              }
            end
          end

          write_json result, 'specs.json'
        end

        no_commands do
          def generate_spec_details(spec)
            data = {
                'id' => spec.id.to_s,
                'operatingSystems' => [],
                'resourceCounts' => {},
                'detectedIssues' => {},
                'testSuites' => []
            }

            spec.operating_systems.each do |os|
              next unless @repo.has_dependency_graph? spec, os

              dg = @repo.dependency_graph spec, os
              write_dg os, dg

              script = @repo.script spec, os
              write_text script, "scripts/#{os}.txt"

              detected_issues = Hash.new{|h, k| h[k] = []}
              resource_count = dg.nodes.size
              data['operatingSystems'] << os.to_s
              data['resourceCounts'][os.to_s] = resource_count

              test_suites = @repo.test_suites spec, os
              test_suites.each do |test_suite|
                test_suite_result = @repo.test_suite_results spec, os, test_suite
                suite_details = generate_test_suite_details spec, os, test_suite, test_suite_result, detected_issues

                data['testSuites'] << {
                    'id' => test_suite.id.to_s,
                    'operatingSystem' => os.to_s,
                    'type' => test_suite.type.to_s,
                    'testCases' => test_suite.test_cases.size,
                    'execs' => test_suite.exec_count,
                    'asserts' => test_suite.assert_count,
                    'status' => test_suite_result.overall_suite_result.to_s,
                    'failingTestCases' => suite_details['failingTestCases'],
                    'failingExecs' => suite_details['failingExecs'],
                    'failingAsserts' => suite_details['failingAsserts'],
                    'totalExecutedSteps' => suite_details['totalExecutedSteps'],
                    'totalExecutionTime' => suite_details['totalExecutionTime']
                }
              end

              non_idempotent_resources = Set.new
              detected_issues.each_key do |property|
                next unless property.type == :idempotence
                non_idempotent_resources << property.resources[0]
              end

              data['detectedIssues'][os.to_s] = []
              detected_issues.each do |property, references|
                next if property.type == :preservation && non_idempotent_resources.include?(property.resources[1])

                data['detectedIssues'][os.to_s] << {
                    'type' => property.type.to_s,
                    'resources' => property.resources.dup,
                    'detectedBy' => references
                }
              end
            end

            write_json data, 'spec.json'
          end

          def generate_test_suite_details(spec, os, test_suite, test_suite_result, detected_issues)
            data = {
                'id' => test_suite.id.to_s,
                'description' => test_suite.name,
                'status' => test_suite_result.overall_suite_result.to_s,
                'testCases' => []
            }

            test_suite.test_cases.each do |test_case|
              result = test_suite_result.overall_case_result test_case
              case_details = generate_test_case_details spec, os, test_suite, test_case, test_suite_result, detected_issues
              data['testCases'] << {
                  'id' => test_case.id.to_s,
                  'execs' => test_case.execs.size,
                  'asserts' => test_case.asserts.size,
                  'failingExecs' => case_details['testSteps'].select { |s| s['status'] == 'failure' && s['type'] == 'exec' }.size,
                  'failingAsserts' => case_details['testSteps'].select { |s| s['status'] == 'failure' && s['type'] == 'assert' }.size,
                  'status' => result.to_s,
                  'executionCount' => case_details['executionCount'],
                  'totalExecutedSteps' => case_details['totalExecutedSteps'],
                  'totalExecutionTime' => case_details['totalExecutionTime']
              }
            end

            data['failingTestCases'] = data['testCases'].select { |c| c['status'] == 'failure' }.size
            data['failingExecs'] = data['testCases'].map { |c| c['failingExecs'] }.reduce(0, :+)
            data['failingAsserts'] = data['testCases'].map { |c| c['failingAsserts'] }.reduce(0, :+)
            data['totalExecutedSteps'] = data['testCases'].map { |c| c['totalExecutedSteps'] }.reduce(0, :+)
            data['totalExecutionTime'] = data['testCases'].map { |c| c['totalExecutionTime'] }.reduce(0, :+)

            write_json data, "testsuites/#{os}/#{test_suite.id}/testsuite.json"
            data
          end

          def generate_test_case_details(spec, os, test_suite, test_case, test_suite_result, detected_issues)
            test_case_results = @repo.test_case_results spec, os, test_suite, test_case
            data = {
                'id' => test_case.id.to_s,
                'status' => test_suite_result.overall_case_result(test_case).to_s,
                'testSteps' => [],
                'executionCount' => test_case_results.size,
                'runs' => [],
                'totalExecutedSteps' => 0,
                'totalExecutionTime' => 0
            }

            test_case.steps.each_with_index do |test_step, step_index|
              execution_count = 0
              execution_times = []
              status = :success
              last_output = ''

              test_case_results.each do |test_case_result|
                next unless test_case_result.step_executed? step_index

                step_result = test_case_result.step_results[step_index]
                status = :failure if step_result.result == :failure

                execution_count += 1
                execution_times << (step_result.execution_time || 0)

                last_output = step_result.output

                if test_step.type == :assert
                  last_output = step_result.assertion_output
                  if step_result.result == :failure
                    detected_issues[test_step.property] << {
                        'testSuiteId' => test_suite.id.to_s,
                        'testCaseId' => test_case.id.to_s,
                        'testStepIndex' => (step_index + 1).to_s
                    }
                  end
                end
              end

              status = :unknown if execution_count == 0

              total_execution_time = execution_times.reduce(0, :+)
              data['testSteps'] << {
                  'id' => step_index.to_s,
                  'type' => test_step.type.to_s,
                  'resource' => test_step.resource,
                  'totalExecutionCount' => execution_count,
                  'averageExecutionTime' => execution_count > 0 ? total_execution_time / execution_count.to_f : 0,
                  'status' => status.to_s
              }

              write_text last_output, "testsuites/#{os}/#{test_suite.id}/testcases/#{test_case.id}/steplastrun#{step_index + 1}.txt"

              data['totalExecutedSteps'] += execution_count
              data['totalExecutionTime'] += total_execution_time
            end

            test_case_results.each_with_index do |test_case_result, index|
              data['runs'] << {
                  'id' => (index + 1).to_s,
                  'executedSteps' => test_case_result.executed_steps,
                  'executionTime' => test_case_result.execution_time,
                  'result' => test_case_result.result.to_s
              }

              write_text test_case_result.to_s, "testsuites/#{os}/#{test_suite.id}/testcases/#{test_case.id}/run#{index + 1}.txt"
            end

            write_json data, "testsuites/#{os}/#{test_suite.id}/testcases/#{test_case.id}/testcase.json"
            data
          end

          def write_dg(os, dg)
            bindata = dg.to_png :tred => true

            path = File.join @out_dir, 'graphs', "#{os}.png"
            FileUtils.makedirs File.dirname(path)

            puts "GENERATING #{path} ...".yellow
            IO.write path, bindata
          end

          def write_json(data, resource)
            json = JSON.generate data
            write_text json, resource
          end

          def write_text(data, resource)
            path = File.join @out_dir, resource
            FileUtils.makedirs File.dirname(path)

            puts "GENERATING #{path} ...".yellow
            puts data if $verbose
            IO.write path, data, :encoding => 'UTF-8'
          end
        end
      end
    end
  end
end