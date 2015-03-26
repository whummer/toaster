require 'set'
require 'tmpdir'
require_relative '../utils/exec'

module Citac
  module Utils
    module FileAccessTracking
      def self.track_accessed_files(command, options = {})
        Dir.mktmpdir do |dir|
          trace_file = File.join dir, 'trace.txt'
          strace_command = "strace -o \"#{trace_file}\" -f -e trace=file #{command}"

          Citac::Utils::Exec.run strace_command, options

          accessed_files = Set.new

          exp = /"(?'value'([^"\\]|\\.)*)"/
          File.open trace_file, 'r' do |file|
            file.each_line do |line|
              line.scan(exp).each do |accessed_file|
                path = File.expand_path(accessed_file[0])
                accessed_files << path
              end
            end
          end

          accessed_files.to_a
        end
      end

      def self.track_modified_files(command, options = {})
        #TODO keep track of directories (create and delete)
        #TODO keep track of deleted files

        Dir.mktmpdir do |dir|
          trace_file = File.join dir, 'trace.txt'
          strace_command = "strace -o \"#{trace_file}\" -f -e trace=write,writev,pwrite -y #{command}"

          Citac::Utils::Exec.run strace_command, options

          modified_files = Set.new

          exp = /\s((write)|(writev)|(pwrite))\(\d+<(?'value'[^>]+)>/
          File.open trace_file, 'r' do |file|
            file.each_line do |line|
              line.scan(exp).each do |accessed_file|
                next if accessed_file[0] =~ /^pipe:\[\d+\]$/

                path = File.expand_path(accessed_file[0])
                modified_files << path
              end
            end
          end

          modified_files.to_a
        end
      end
    end
  end
end