require 'thor'
require_relative '../../commons/utils/exec'
require_relative '../../commons/utils/serialization'
require_relative 'changetracker'

module Citac
  module ChangeTrackers
    module Docker
      class CLI < Thor
        desc 'track <summary file> <settings file> <cmd> <arg1> <arg2> ...', 'Tracks changes of the given command.'
        def track(summary_file, settings_file, *cmd)
          cmdstr = Citac::Utils::Exec.format_args cmd
          puts "Executing '#{cmdstr}' and tracking its changes..."

          settings = Citac::Utils::Serialization.load_from_file settings_file

          change_summary, result = ChangeTracker.track_changes cmd, settings, :output => :passthrough, :raise_on_failure => false

          puts "Writing change summary to '#{args[0]}'..."
          Citac::Utils::Serialization.write_to_file change_summary, summary_file

          exit result.exit_code
        end

        desc 'capture <state file>', 'Captures the system state for later analyzation.'
        def capture(state_file)
          state = ChangeTracker.capture_pre_state
          Citac::Utils::Serialization.write_to_file state, state_file
        end

        option :keepstate, :type => :boolean, :desc => 'keeps the state file for further analyzes'
        desc 'analyze <state file> <trace file> <settings file> <summary file>', 'Analyzes state changes by using the previously captured system state.'
        def analyze(state_file, trace_file, settings_file, summary_file)
          snapshot_image, transient_pre_state = Citac::Utils::Serialization.load_from_file state_file
          settings = Citac::Utils::Serialization.load_from_file settings_file

          accessed_files, syscalls = Citac::Integration::Strace.parse_trace_file trace_file,
            :start_markers => settings.start_markers, :end_markers => settings.end_markers

          change_summary = ChangeTracker.analyze snapshot_image, transient_pre_state, accessed_files, syscalls, settings
          Citac::Utils::Serialization.write_to_file change_summary, summary_file
        ensure
          clear state_file unless options[:keepstate]
        end

        desc 'clear <state file>', 'Clears the state.'
        def clear(state_file)
          if File.exists? state_file
            snapshot_image, _ = Citac::Utils::Serialization.load_from_file state_file
            ChangeTracker.remove_snapshot_image snapshot_image
            File.delete state_file
          end
        end
      end
    end
  end
end