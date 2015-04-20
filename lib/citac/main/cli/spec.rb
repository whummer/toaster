require 'thor'
require_relative '../ioc'
require_relative '../../commons/model'
require_relative '../tasks/analyzation'
require_relative '../tasks/execution'

module Citac
  module Main
    module CLI
      class Spec < Thor
        def initialize(*args)
          super

          @repo = ServiceLocator.specification_repository
          @env_mgr = ServiceLocator.environment_manager
          @exec_mgr = ServiceLocator.execution_manager
          @spec_service = ServiceLocator.specification_service
        end

        desc 'list', 'Lists all stored configuration specifications.'
        def list
          @repo.each_spec do |spec_name|
            puts spec_name
          end
        end

        desc 'info <id>', 'Prints information about the stored configuration specification.'
        def info(spec_id)
          spec = @repo.get spec_id
          run_count = @repo.run_count spec

          puts "Id:\t#{spec.id}"
          puts "Name:\t#{spec.name}"
          puts "Type:\t#{spec.type}"
          puts "Runs:\t#{run_count}"

          oss = @env_mgr.operating_systems spec.type
          puts 'Operating systems:'
          spec.operating_systems.each do |os|
            next unless oss.include? os

            msg = "  - #{os}"
            msg << ' (analyzed)' if @repo.has_dependency_graph? spec, os

            puts msg
          end
        end

        desc 'resources <spec> <os>', 'Prints a list of the configuration specification resources.'
        def resources(spec_id, os = nil)
          spec = @repo.get spec_id
          os = Citac::Model::OperatingSystem.parse os if os

          dg = @spec_service.dependency_graph spec, os
          dg.resources.each do |resource|
            puts resource
          end
        end

        option :force, :type => :boolean, :aliases => :f
        desc 'analyze [--force|-f] <spec> [<os>]', 'Generates the dependency graph for the given configuration specification.'
        def analyze(spec_id, os = nil)
          spec = @repo.get spec_id
          os = Citac::Model::OperatingSystem.parse os if os

          task = Citac::Main::Tasks::AnalyzationTask.new @repo, spec
          @exec_mgr.execute task, os, :output => :passthrough
        end

        option :stepwise, :aliases => :s, :type => :boolean, :desc => 'Enables stepwise execution.'
        desc 'exec [-s] <spec> <os>', 'Runs the given configuration specification on the specified operating system.'
        def exec(spec_id, os = nil)
          spec =  @repo.get spec_id
          os = Citac::Model::OperatingSystem.parse os if os

          task = Citac::Main::Tasks::ExecutionTask.new spec
          task.stepwise = options[:stepwise]

          @exec_mgr.execute task, os, :output => :passthrough
        end
      end
    end
  end
end