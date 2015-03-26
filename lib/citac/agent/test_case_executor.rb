require 'fileutils'
require 'tmpdir'
require 'yaml'
require_relative '../providers'
require_relative '../utils/graph'
require_relative '../utils/colorize'
require_relative '../logging'

module Citac
  module Agent
    class TestCaseExecutor
      def initialize(repository, env_manager)
        @repository = repository
        @env_manager = env_manager
      end

      def run(spec, operating_system, test_case, options = {})
        log_info 'agent', "Running '#{test_case}' for '#{spec}' on '#{operating_system}'..."
        puts "Running test '#{test_case.name}' for '#{spec}' on '#{operating_system}'...".yellow

        provider = Citac::Providers.get spec.type

        Dir.mktmpdir do |dir|
          log_debug 'agent', "Using temporary directory '#{dir}'..."

          run_script_path = File.join(dir, 'run.sh')

          File.open run_script_path, 'w', :encoding => 'UTF-8' do |f|
            f.puts '#!/bin/sh'
            f.puts 'cd /tmp/citac'

            provider.prepare_for_test_case_execution @repository, spec, dir, f, :print => options[:print]
          end

          script_name = "script#{provider.script_extension}"
          script_path = File.join(dir, script_name)
          script_contents = @repository.script spec, operating_system
          IO.write script_path, script_contents, :encoding => 'UTF-8'

          test_case_path = File.join(dir, 'test_case.yml')
          test_case_contents = test_case.to_yaml
          IO.write test_case_path, test_case_contents, :encoding => 'UTF-8'

          env = @env_manager.find :operating_system => operating_system, :spec_runner => spec.type

          log_info 'agent', "Running test case in environment '#{env}'..."
          start_time = Time.now
          instance = @env_manager.run env, run_script_path, :output => :passthrough, :raise_on_failure => false
          result = instance.run_result
          end_time = Time.now

          run = @repository.save_run spec, operating_system, 'test', result, start_time, end_time

          test_case_result = YAML.load_file File.join(dir, 'test_case_result.yml')
          #puts IO.read File.join(dir, 'test_case_result.yml'), :encoding => 'UTF-8'
          #TODO save test_case_result with run

          if result.success?
            if test_case_result.success?
              puts "Done. Test '#{test_case.name}' successful.".green
            else
              puts "Done. Test '#{test_case.name}' not successful.".red
            end
          else
            errors = result.errors.join($/)
            raise "Test case '#{test_case.name}' of #{spec} on #{operating_system} failed. See run output for details.#{$/}#{errors}"
          end
        end
      end
    end
  end
end