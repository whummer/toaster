require 'stringio'
require 'tmpdir'
require_relative '../../../commons/integration/puppet'
require_relative '../../../commons/model/change_tracking'
require_relative '../../../commons/utils/exec'
require_relative '../../../commons/utils/serialization'

module Citac
  module Agents
    module Puppet
      class AssertionResult
        def initialize(resource_name, exec_result, change_summary)
          @resource_name = resource_name
          @exec_result = exec_result
          @change_summary = change_summary
        end

        def success?
          @exec_result.success? && @change_summary.changes.empty?
        end

        def output
          result = StringIO.new

          result.puts '- - - - - - - - -'
          result.puts 'Summary'
          result.puts '- - - - - - - - -'
          result.puts
          result.puts status_text
          result.puts
          result.puts '- - - - - - - - -'
          result.puts 'Change Summary'
          result.puts '- - - - - - - - -'
          result.puts
          result.puts @change_summary
          result.puts
          result.puts '- - - - - - - - -'
          result.puts 'Puppet output'
          result.puts '- - - - - - - - -'
          result.puts
          result.puts @exec_result.output

          @change_summary.additional_data.each do |key, data|
            result.puts
            result.puts '- - - - - - - - -'
            result.puts 'Additional data'
            result.puts key
            result.puts '- - - - - - - - -'
            result.puts
            result.puts data
          end

          result.string
        end

        def to_s
          result = status_text

          unless @exec_result.success?
            result << $/
            result << @exec_result.output
          end

          result
        end

        private

        def status_text
          result = StringIO.new

          if @exec_result.success?
            result.puts "Execution of '#{@resource_name}' was successful."
          else
            result.puts "Execution of '#{@resource_name}' failed."
          end

          if @change_summary.changes.empty?
            result.puts 'No changes were detected.'
          else
            result.puts "#{@change_summary.changes.size} changes were detected:"
            @change_summary.changes.each {|c| result.puts "  - #{c}"}
          end

          result.string
        end
      end

      class AssertionTask
        attr_accessor :file_exclusion_patterns, :state_exclusion_patterns

        def initialize(manifest_path, resource_name)
          @manifest_path = manifest_path
          @resource_name = resource_name
          @file_exclusion_patterns = []
          @state_exclusion_patterns = []
        end

        def execute(options = {})
          Dir.mktmpdir do |dir|
            change_summary_path = File.join dir, 'change_summary.yml'
            trace_file = File.join dir, 'trace.txt'

            settings_path = File.join dir, 'settings.yml'
            
            change_tracking_settings = Citac::Model::ChangeTrackingSettings.new
            change_tracking_settings.file_exclusion_patterns = @file_exclusion_patterns
            change_tracking_settings.state_exclusion_patterns = @state_exclusion_patterns
            change_tracking_settings.start_markers << /CITAC_RESOURCE_EXECUTION_START/
            change_tracking_settings.end_markers << /CITAC_RESOURCE_EXECUTION_END/
            change_tracking_settings.command_generated_trace_file = trace_file
            Citac::Utils::Serialization.write_to_file change_tracking_settings, settings_path

            apply_opts = options.dup
            apply_opts[:resource] = @resource_name
            apply_opts[:trace_file] = trace_file

            args = Citac::Integration::Puppet.apply_args @manifest_path, apply_opts
            args = ['track', change_summary_path, settings_path, 'citac-puppet'] + args

            exec_opts = options.dup
            exec_opts[:raise_on_failure] = false
            exec_opts[:args] = args

            result = Citac::Utils::Exec.run 'citac-changetracker', exec_opts

            if File.exists? change_summary_path
              change_summary = Citac::Utils::Serialization.load_from_file change_summary_path
              return AssertionResult.new @resource_name, result, change_summary
            else
              raise "Change tracker failed: #{result.output}"
            end
          end
        end
      end
    end
  end
end