require 'thor'
require_relative '../ioc'

module Citac
  module Main
    module CLI
      class Runs < Thor
        def initialize(*args)
          super
          @repo = ServiceLocator.specification_repository
        end

        option :bulk, :type => :boolean, :aliases => :b
        option :quiet, :type => :boolean, :aliases => :q
        option :os, :aliases => :o
        option :action, :aliases => :a
        option :failed, :type => :boolean, :aliases => :f
        option :successful, :type => :boolean, :aliases => :s
        desc 'list [-b] [-q] [-s|-f] [-a <action>] [-os <os>] <id>', 'Prints all performed runs of the given configuration specification.'
        def list(spec_id)
          raise 'Conflicting filter: failed and successful' if options[:successful] && options[:failed]

          if options[:bulk]
            lens = []
            @repo.each_spec {|s| lens << s.length}
            len = lens.max
          end

          spec = @repo.get spec_id

          runs = @repo.runs(spec)
          filter_runs! runs, options

          puts "Action\t\tExit Code\tOS\tStart Time\t\t\tDuration" unless options[:bulk] || runs.size == 0
          puts "======\t\t=========\t==\t==========\t\t\t========" unless options[:bulk] || runs.size == 0

          runs.sort_by! {|run| run.id}

          if runs.size > 0
            prefix = options[:bulk] ? "#{spec.to_s.ljust(len)}\t" : ''

            runs.each do |run|
              puts "#{prefix}#{run.action}\t\t#{run.exit_code}\t\t#{run.operating_system}\t#{run.start_time}\t#{run.duration.round(2).to_s.rjust(6)} s"
            end
          elsif !options[:quiet]
            if options[:bulk]
              puts "#{spec.to_s.ljust(len)}\tNo runs found."
            else
              puts "No runs of #{spec} found."
            end
          end
        end

        option :os, :aliases => :o
        option :action, :aliases => :a
        option :failed, :type => :boolean, :aliases => :f
        option :successful, :type => :boolean, :aliases => :s
        desc 'clear <id>', 'Clears all saved runs of the given configuration specification.'
        def clear(spec_id)
          spec = @repo.get spec_id
          run_count = @repo.run_count spec

          puts "Deleting matching runs of #{spec}..."
          count = 0

          runs = @repo.runs(spec)
          filter_runs! runs, options
          runs.each do |run|
            @repo.delete_run run
            count += 1
          end

          puts "Deleted #{count} out of #{run_count} runs."
        end

        no_commands do
          def filter_runs!(runs, options)
            runs.select! {|run| run.exit_code == 0} if options[:successful]
            runs.reject! {|run| run.exit_code == 0} if options[:failed]
            runs.select! {|run| run.action == options[:action]} if options[:action]

            if options[:os]
              os = Citac::Model::OperatingSystem.parse options[:os]
              runs.select!{|run| run.operating_system.matches? os}
            end
          end
        end
      end
    end
  end
end