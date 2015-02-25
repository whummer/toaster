require 'fileutils'
require_relative '../providers'
require_relative '../utils/graph'
require_relative '../utils/colorize'
require_relative '../logging'

module Citac
  module Agent
    class Runner
      def trace?; @trace; end
      def trace=(value); @trace = value; end

      def initialize(repository, env_manager)
        @repository = repository
        @env_manager = env_manager
        @trace = false
      end

      def run(spec, operating_system)
        log_info 'agent', "Running configuration specification '#{spec}' on operating system '#{operating_system}'..."

        provider = Citac::Providers.get spec.type

        script_name = "script#{provider.script_extension}"
        script_contents = @repository.script spec, operating_system

        Dir.mktmpdir do |dir|
          log_debug 'agent', "Using temporary directory '#{dir}'..."

          run_script_path = File.join(dir, 'run.sh')
          log_debug 'agent', "Writing run script '#{run_script_path}'..."

          File.open run_script_path, 'w', :encoding => 'UTF-8' do |f|
            f.puts '#!/bin/sh'
            f.puts 'cd /tmp/citac'

            provider.prepare_for_run @repository, spec, dir, f, :trace => @trace
          end

          run_script_contents = IO.read run_script_path, :encoding => 'UTF-8'
          log_debug 'agent', "Run script:\n--EOF--\n#{run_script_contents}\n--EOF--"

          script_path = File.join(dir, script_name)
          IO.write script_path, script_contents, :encoding => 'UTF-8'

          log_debug 'agent', "Configuration run script '#{script_path}':\n--EOF--\n#{script_contents}\n--EOF--"

          env = @env_manager.find :operating_system => operating_system, :spec_runner => spec.type

          log_info 'agent', "Running configuration specification in environment '#{env}'..."
          start_time = Time.now
          instance = @env_manager.run env, run_script_path, :output => :passthrough, :raise_on_failure => false
          result = instance.run_result
          end_time = Time.now

          run = @repository.save_run spec, operating_system, 'exec', result, start_time, end_time
          if @trace
            trace_json = IO.read File.join(dir, 'trace.json'), :encoding => 'UTF-8'
            @repository.save_run_trace spec, run, trace_json
          end

          unless result.success?
            if @trace && result.output.include?('strace')
              puts "strace failed. Run 'aa-complain /etc/apparmor.d/docker' and try again.".yellow
            end

            errors = result.errors.join($/)
            raise "Execution of #{spec} on #{operating_system} failed. See run output for details.#{$/}#{errors}"
          end
        end
      end
    end
  end
end