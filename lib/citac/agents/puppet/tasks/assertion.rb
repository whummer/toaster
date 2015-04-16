require 'stringio'
require 'tmpdir'
require_relative '../../../commons/integration/puppet'
require_relative '../../../commons/model/change_summary'
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

          result.puts '=================================================================='
          result.puts 'Summary'
          result.puts '=================================================================='
          result.puts
          result.puts status_text
          result.puts
          result.puts '=================================================================='
          result.puts 'Change Summary'
          result.puts '=================================================================='
          result.puts
          result.puts @change_summary
          result.puts
          result.puts '=================================================================='
          result.puts 'Puppet output'
          result.puts '=================================================================='
          result.puts
          result.puts @exec_result.output

          result.string
        end

        def to_s
          status_text
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
        def initialize(manifest_path, resource_name, exclusion_patterns)
          @manifest_path = manifest_path
          @resource_name = resource_name
          @exclusion_patterns = exclusion_patterns
        end

        def execute(options = {})
          Dir.mktmpdir do |dir|
            change_summary_path = File.join dir, 'change_summary.yml'

            exclusion_patterns_path = File.join dir, 'exclusion_patterns.yml'
            Citac::Utils::Serialization.write_to_file @exclusion_patterns, exclusion_patterns_path

            apply_opts = options.dup
            apply_opts[:resource] = @resource_name

            args = Citac::Integration::Puppet.apply_args @manifest_path, apply_opts
            args = [change_summary_path, exclusion_patterns_path, 'citac-puppet'] + args

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