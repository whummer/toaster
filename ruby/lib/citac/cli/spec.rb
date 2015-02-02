require 'thor'
require_relative 'ioc'
require_relative '../agent/analyzation'

module Citac
  module CLI
    class Spec < Thor
      desc 'list', 'Lists all stored configuration specifications.'
      def list
        ServiceLocator.specification_repository.each_spec do |spec_name|
          puts spec_name
        end
      end

      desc 'info <id>', 'Prints information about the stored configuration specification.'
      def info(spec_id)
        repo = ServiceLocator.specification_repository
        spec = repo.get spec_id

        puts "Id:\t#{spec.id}"
        puts "Name:\t#{spec.name}"
        puts "Type:\t#{spec.type}"

        puts 'Operating systems:'
        spec.operating_systems.each do |os|
          msg = "  - #{os}"
          msg << ' (analyzed)' if repo.has_dependency_graph? spec, os.name, os.version

          puts msg
        end
      end

      desc 'analyze <spec> [<os>]', 'Generates the dependency graph for the given configuration specification.'
      def analyze(spec_name, os_name, os_version)
        repo = ServiceLocator.specification_repository
        env_mgr = ServiceLocator.environment_manager

        spec = repo.get spec_name

        analyzer = Citac::Agent::Analyzer.new repo, env_mgr
        analyzer.run spec, os_name, os_version
      end
    end
  end
end