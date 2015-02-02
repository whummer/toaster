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

      def run(spec, os_name, os_version)
        log_info 'agent', "Starting to analyze configuration specification '#{spec}' on os '#{os_name}-#{os_version}'..."

        provider = Citac::Providers.get spec.type

        script_name = "script#{provider.script_extension}"
        script_contents = @repository.script spec, os_name, os_version

        Dir.mktmpdir do |dir|
          log_debug 'agent', "Using temporary directory '#{dir}'..."

          run_script_path = File.join(dir, 'run.sh')
          log_debug 'agent', "Writing run script '#{run_script_path}'..."

          File.open run_script_path, 'w', :encoding => 'UTF-8' do |f|
            f.puts '#!/bin/sh'
            f.puts 'gem install --no-ri --no-rdoc thor rest-client'
            f.puts 'cd /tmp/citac'

            provider.write_preparation_code f, spec
            provider.write_dependency_graph_code f, script_name, 'dependencies.graphml'
          end

          run_script_contents = IO.read run_script_path, :encoding => 'UTF-8'
          log_debug 'agent', "Run script:\n--EOF--\n#{run_script_contents}\n--EOF--"

          script_path = File.join(dir, script_name)
          IO.write script_path, script_contents, :encoding => 'UTF-8'

          log_debug 'agent', "Analyzation script '#{script_path}':\n--EOF--\n#{script_contents}\n--EOF--"

          env = @env_manager.find os_name, os_version, spec.type

          log_info 'agent', "Running analyzation in environment '#{env}'..."
          output = @env_manager.run env, run_script_path
          log_debug 'agent', "Run script output:\n--EOF--\n#{output}\n--EOF--"

          dependencies_graphml = IO.read File.join(dir, 'dependencies.graphml'), :encoding => 'UTF-8'
          dependencies = Citac::Utils::Graphs::Graph.from_graphml dependencies_graphml

          log_info 'agent', "Saving generated dependency graph for '#{spec}' to repository..."
          @repository.save_dependency_graph spec, os_name, os_version, dependencies
        end
      end
    end
  end
end