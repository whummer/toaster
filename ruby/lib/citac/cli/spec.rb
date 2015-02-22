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
        spec_id = clean_spec_id spec_id

        repo = ServiceLocator.specification_repository

        spec = repo.get spec_id
        run_count = repo.run_count spec

        puts "Id:\t#{spec.id}"
        puts "Name:\t#{spec.name}"
        puts "Type:\t#{spec.type}"
        puts "Runs:\t#{run_count}"

        env_mgr = ServiceLocator.environment_manager
        oss = env_mgr.operating_systems spec.type
        puts 'Operating systems:'
        spec.operating_systems.each do |os|
          next unless oss.include? os

          msg = "  - #{os}"
          msg << ' (analyzed)' if repo.has_dependency_graph? spec, os

          puts msg
        end
      end

      option :bulk, :type => :boolean, :aliases => :b
      desc 'runs [-b] <id>', 'Prints all performed runs of the given configuration specification.'
      def runs(spec_id)
        spec_id = clean_spec_id spec_id

        repo = ServiceLocator.specification_repository

        if options[:bulk]
          lens = []
          repo.each_spec { |s| lens << s.length}
          len = lens.max
        end

        spec = repo.get spec_id

        if repo.run_count(spec) > 0
          puts "Action\t\tExit Code\tOS\tStart Time\t\t\tDuration" unless options[:bulk]
          puts "======\t\t=========\t==\t==========\t\t\t========" unless options[:bulk]

          prefix = options[:bulk] ? "#{spec.to_s.ljust(len)}\t" : ''
          repo.runs(spec).each do |run|
            puts "#{prefix}#{run.action}\t\t#{run.exit_code}\t\t#{run.operating_system}\t#{run.start_time}\t#{run.duration.round(2).to_s.rjust(6)} s"
          end
        else
          if options[:bulk]
            puts "#{spec.to_s.ljust(len)}\tNo runs found."
          else
            puts "No runs of #{spec} found."
          end
        end
      end

      desc 'clearruns <id>', 'Clears all saved runs of the given configuration specification.'
      def clearruns(spec_id)
        spec_id = clean_spec_id spec_id

        repo = ServiceLocator.specification_repository
        spec = repo.get spec_id

        puts "Deleting all runs of #{spec}..."

        repo.runs(spec).each do |run|
          repo.delete_run run
        end
      end

      option :force, :type => :boolean, :aliases => :f
      desc 'analyze [--force|-f] <spec> [<os>]', 'Generates the dependency graph for the given configuration specification.'
      def analyze(spec_name, os = nil)
        spec_name = clean_spec_id spec_name

        os = Citac::Model::OperatingSystem.parse os if os

        repo = ServiceLocator.specification_repository
        env_mgr = ServiceLocator.environment_manager

        spec = repo.get spec_name

        oss = env_mgr.operating_systems(spec.type).to_a
        oss.select! {|o| spec.operating_systems.include? o} unless spec.operating_systems.empty?
        oss.select! {|o| o.matches? os} if os

        if oss.any?
          analyzer = Citac::Agent::Analyzer.new repo, env_mgr
          oss.each do |os|
            analyzer.run spec, os, :force => options[:force]
          end
        else
          puts "No compatible operating system found for #{spec}."
        end
      end

      desc 'exec <spec> <os>', 'Runs the given configuration specification on the specified operating system.'
      def exec(spec_name, os = nil)
        spec_name = clean_spec_id spec_name

        repo = ServiceLocator.specification_repository
        env_mgr = ServiceLocator.environment_manager

        spec = repo.get spec_name

        if os
          os = Citac::Model::OperatingSystem.parse os

          unless os.specific?
            real_os = env_mgr.operating_systems(spec.type).find{|o| o.matches? os}
            raise "No operating system matching '#{os}' found" unless real_os

            os = real_os
          end
        else
          oss = env_mgr.operating_systems spec.type
          os = oss.first {|o| o.matches? os}

          raise "No suitable environment found for executiong #{spec}" unless os
        end

        puts "Executing #{spec} on #{os}..."

        runner = Citac::Agent::Runner.new repo, env_mgr
        runner.run spec, os
      end

      no_commands do
        def clean_spec_id(spec_id)
          spec_id.gsub /\.spec\/?/i, ''
        end
      end
    end
  end
end