require 'thor'
require_relative 'ioc'
require_relative '../agent/analyzation'
require_relative '../agent/runner'
require_relative '../model'

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
          msg << ' (analyzed)' if repo.has_dependency_graph? spec, os

          puts msg
        end
      end

      option :force, :type => :boolean, :aliases => :f
      desc 'analyze [--force|-f] <spec> [<os>]', 'Generates the dependency graph for the given configuration specification.'
      def analyze(spec_name, os = nil)
        os = Citac::Model::OperatingSystem.parse os if os

        repo = ServiceLocator.specification_repository
        env_mgr = ServiceLocator.environment_manager

        spec = repo.get spec_name

        oss = env_mgr.operating_systems(spec.type).to_a
        oss.select! {|o| spec.operating_systems.include? o}
        oss.select! {|o| o.matches? os} if os

        analyzer = Citac::Agent::Analyzer.new repo, env_mgr
        oss.each do |os|
          analyzer.run spec, os, :force => options[:force]
        end
      end

      desc 'exec <spec> <os>', 'Runs the given configuration specification on the specified operating system.'
      def exec(spec_name, os)
        os = Citac::Model::OperatingSystem.parse os

        repo = ServiceLocator.specification_repository
        env_mgr = ServiceLocator.environment_manager

        spec = repo.get spec_name

        unless os.specific?
          real_os = env_mgr.operating_systems(spec.type).find{|o| o.matches? os}
          raise "No operating system matching '#{os}' found" unless real_os

          os = real_os
        end

        runner = Citac::Agent::Runner.new repo, env_mgr
        runner.run spec, os
      end
    end
  end
end