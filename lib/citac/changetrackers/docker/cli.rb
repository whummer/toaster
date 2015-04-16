require_relative '../../commons/utils/exec'
require_relative '../../commons/utils/serialization'
require_relative 'changetracker'

module Citac
  module ChangeTrackers
    module Docker
      class CLI
        def self.start(args)
          cmd = Citac::Utils::Exec.format_args args.drop(2)
          puts "Executing '#{cmd}' and tracking its changes..."

          settings = Citac::Utils::Serialization.load_from_file args[1]

          change_summary, result = ChangeTracker.track_changes args.drop(2), settings, :output => :passthrough, :raise_on_failure => false

          puts "Writing change summary to '#{args[0]}'..."
          Citac::Utils::Serialization.write_to_file change_summary, args[0]

          exit result.exit_code
        end
      end
    end
  end
end