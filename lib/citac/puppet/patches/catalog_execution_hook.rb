require 'puppet/resource/catalog'
require 'tmpdir'
require_relative '../../commons/utils/colorize'
require_relative '../../commons/utils/exec'
require_relative '../../commons/utils/serialization'
require_relative '../../commons/model'

class Puppet::Resource::Catalog < Puppet::Graph::SimpleGraph
  alias_method :__citac_apply_original, :apply

  def apply(options = {})
    if host_config? && $__citac_test_case
      __citac_apply_test_case $__citac_test_case, $__citac_test_case_result_file, $__citac_test_case_settings_file, options
    else
      __citac_apply_original options
    end
  end

  def __citac_apply_test_case(test_case, test_case_result_file, settings_file, options)
    Dir.mktmpdir do |dir|
      state_file = File.join dir, 'state.yml'
      trace_file = File.join dir, 'trace.txt'
      summary_file = File.join dir, 'change_summary.yml'

      test_case_result = Citac::Model::TestCaseResult.new test_case

      test_case.steps.each_with_index do |step, index|
        start_time = Time.now

        if step.type == :exec
          puts "Step #{index + 1} / #{test_case.steps.size}: #{step}...".yellow

          $citac_apply_single_trace = false
          $citac_apply_single_trace_file = nil
        elsif step.type == :assert
          puts "Step #{index + 1} / #{test_case.steps.size}: #{step}: #{step.property}...".yellow

          File.delete trace_file if File.exists? trace_file
          File.delete summary_file if File.exists? summary_file

          if test_case.steps[index - 1].type != :assert
            Citac::Utils::Exec.run 'citac-changetracker capture', :args => [state_file]
          end

          $citac_apply_single_trace = true
          $citac_apply_single_trace_file = trace_file
        else
          raise "Step #{step} has unknown type: #{step.type}"
        end

        exit_code = __citac_run_step step, options
        success = exit_code == 0
        output = nil #TODO output will be captured later, but we could also fork here.

        if step.type == :exec
          test_case_result.add_step_result step, success, output
        elsif step.type == :assert
          args = [state_file, trace_file, settings_file, summary_file]
          args << '--keepstate' if index + 1 < test_case.steps.size && test_case.steps[index + 1].type == :assert
          Citac::Utils::Exec.run 'citac-changetracker analyze', :args => args
          change_summary = Citac::Utils::Serialization.load_from_file summary_file

          puts change_summary unless change_summary.changes.empty?

          success &&= change_summary.changes.empty?
          test_case_result.add_step_result step, success, output, change_summary
        end

        end_time = Time.now

        if success
          puts "OK (#{end_time - start_time} seconds)".green
        else
          puts "FAIL (#{end_time - start_time} seconds)".red
          break
        end
      end

      Citac::Utils::Exec.run 'citac-changetracker clear', :args => [state_file], :raise_on_failure => false

      test_case_result.finish
      Citac::Utils::Serialization.write_to_file test_case_result, test_case_result_file
    end
  end

  def __citac_run_step(test_step, options)
    $citac_apply_single = true
    $citac_apply_single_resource_name = test_step.resource

    begin
      __citac_apply_original options
      exit_code = 0
    rescue SystemExit => e
      exit_code = e.status
      exit_code = 0 if exit_code == 2
    end

    exit_code
  end
end