require 'thor'
require_relative '../data/filesystem'
require_relative '../environments/docker'
require_relative '../agent/analyzation'

module Citac
  module CLI
    class Spec < Thor
      desc 'list', 'Lists all stored configuration specifications.'
      def list
        repository.each_spec do |spec_name|
          puts spec_name
        end
      end

      desc 'info <id>', 'Prints information about the stored configuration specification.'
      def info(spec_id)
        spec = repository.get spec_id
        puts "Id:\t#{spec.id}"
        puts "Name:\t#{spec.name}"
        puts "Type:\t#{spec.type}"

        puts 'Operating systems:'
        spec.operating_systems.each do |os|
          puts "  - #{os}"
        end
      end

      desc 'analyze <spec>', 'Generates the dependency graph for the given configuration specification.'
      def analyze(spec_name, os_name, os_version)
        spec = repository.get spec_name

        env_mgr = Citac::Environments::DockerEnvironmentManager.new

        analyzer = Citac::Agent::Analyzer.new repository, env_mgr
        analyzer.run spec, os_name, os_version
      end

      no_commands do
        def repository
          path = '/home/oliver/Projects/citac/test-cases'  #TODO determine path
          @repo = Citac::Data::FileSystemSpecificationRepository.new path unless @repo
          @repo
        end
      end
    end
  end
end