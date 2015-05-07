require_relative 'execution'
require_relative 'assertion'
require_relative '../../../commons/utils/colorize'
require_relative '../../../commons/integration/puppet'
require_relative '../../../commons/model'

module Citac
  module Agents
    module Puppet
      class TestTask
        attr_accessor :file_exclusion_patterns, :state_exclusion_patterns

        def initialize(manifest_path, test_case)
          @manifest_path = manifest_path
          @test_case = test_case
          @file_exclusion_patterns = []
          @state_exclusion_patterns = []
        end

        def execute(options = {})
          puppet_opts = options.dup
          puppet_opts[:raise_on_failure] = false

          test_case_result = Citac::Model::TestCaseResult.new @test_case
          @test_case.steps.each_with_index do |step, index|
            puts "Step #{index + 1} / #{@test_case.steps.size}: #{step}...".yellow

            case step.type
              when :exec
                task = ExecutionTask.new @manifest_path, step.resource
                result = task.execute puppet_opts
              when :assert
                task = AssertionTask.new @manifest_path, step.resource
                task.file_exclusion_patterns = @file_exclusion_patterns
                task.state_exclusion_patterns = @state_exclusion_patterns
                result = task.execute puppet_opts
              else
                raise "Unknown step type: #{step.type}"
            end

            test_case_result.add_step_result step, result.success?, result.output
            if result.success?
              puts 'OK'.green
            else
              puts 'FAIL'.red
              $stdout.flush
              $stderr.puts result
              break
            end
          end

          test_case_result.finish
          test_case_result
        end
      end
    end
  end
end