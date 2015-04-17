require_relative '../../commons/utils/exec'

module Citac
  module Main
    module Tasks
      class ExecutionManager
        def initialize(repository, env_manager)
          @repository = repository
          @env_manager = env_manager
        end

        def execute(task, operating_system = nil, options = {})
          env = @env_manager.find :operating_system => operating_system, :spec_runner => task.spec.type
          operating_system = env.operating_system

          log_debug 'exec-mgr', "Running '#{task.spec}' (#{task.type}) in environment '#{env}'..."
          puts "Running '#{task.spec}' (#{task.type}) on '#{operating_system}'..."

          Dir.mktmpdir do |dir|
            @repository.get_additional_files task.spec, dir

            run_script_path = File.join dir, 'run.sh'
            File.open run_script_path, 'w', :encoding => 'UTF-8' do |f|
              flags = []
              flags << '-v' if $verbose
              flags += task.additional_args if task.respond_to? :additional_args
              flags = Citac::Utils::Exec.format_args flags

              f.puts '#!/bin/sh'
              f.puts 'cd /tmp/citac'
              f.puts "citac-agent-#{task.spec.type} #{task.type} #{flags}"
            end

            script_path = File.join dir, 'script'
            script_contents = @repository.script task.spec, operating_system
            IO.write script_path, script_contents, :encoding => 'UTF-8'

            task.before_execution dir, operating_system if task.respond_to? :before_execution

            run_opts = options.dup
            run_opts[:raise_on_failure] = false

            start_time = Time.now
            instance = @env_manager.run env, run_script_path, run_opts
            end_time = Time.now
            result = instance.run_result

            run = @repository.save_run task.spec, operating_system, task.type, result, start_time, end_time

            task_result = nil
            task_result = task.after_execution dir, operating_system, result, run if result.success? && task.respond_to?(:after_execution)

            unless result.success?
              raise "Execution of '#{task.spec}' (#{task.type}) on '#{operating_system}' failed.#{$/}#{result.output}"
            end

            task_result
          end
        end
      end
    end
  end
end