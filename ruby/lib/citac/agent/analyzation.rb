require 'fileutils'
require_relative '../providers'
require_relative '../utils/graph'
require_relative '../logging'

module Citac
  module Agent
    class Analyzer
      def initialize(repository, env_manager)
        @repository = repository
        @env_manager = env_manager
      end

      def run(spec, operating_system, options = {})
        raise "Operating system '#{operating_system}' not specific" unless operating_system.specific?

        if @repository.has_dependency_graph?(spec, operating_system) && !options[:force]
          puts "Skipping analyzation of #{spec} on #{operating_system} because a dependency graph is already present."
          return
        end

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

            provider.prepare_for_dependency_graph_generation @repository, spec, dir, f
          end

          run_script_contents = IO.read run_script_path, :encoding => 'UTF-8'
          log_debug 'agent', "Run script:\n--EOF--\n#{run_script_contents}\n--EOF--"

          script_path = File.join(dir, script_name)
          IO.write script_path, script_contents, :encoding => 'UTF-8'

          log_debug 'agent', "Analyzation script '#{script_path}':\n--EOF--\n#{script_contents}\n--EOF--"

          env = @env_manager.find :operating_system => operating_system, :spec_runner => spec.type

          puts "Analyzing #{spec} in environment '#{env}'..."
          log_info 'agent', "Running analyzation in environment '#{env}'..."

          start_time = Time.now
          result = @env_manager.run env, run_script_path, :raise_on_failure => false
          end_time = Time.now

          log_debug 'agent', "Run script output:\n--EOF--\n#{result.output}\n--EOF--"

          @repository.save_run spec, operating_system, 'analyze', result, start_time, end_time

          unless result.success?
            errors = result.output.each_line.select{|l| l =~ /error/i}.join
            raise "Analyzing #{spec} on #{operating_system} failed. See run output for details.#{$/}#{errors}"
          end

          dependencies_graphml = IO.read File.join(dir, 'dependencies.graphml'), :encoding => 'UTF-8'
          dependencies = Citac::Utils::Graphs::Graph.from_graphml dependencies_graphml

          puts "Saving generated dependency graph for #{spec} to repository..."
          log_info 'agent', "Saving generated dependency graph for '#{spec}' to repository..."

          @repository.save_dependency_graph spec, operating_system, dependencies

          puts 'Done.'
        end
      end
    end
  end
end