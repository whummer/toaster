require 'set'
require 'tmpdir'
require_relative 'parser'
require_relative 'runner'
require_relative '../../logging'

module Citac
  module Integration
    module Strace
      SINGLE_FILE_ARGUMENT_SYSCALLS = %w(execve readlink)

      def self.track_file_access(command, options = {})
        run_opts = options.dup
        run_opts[:syscalls] = :file
        run_opts[:signals] = :none

        accessed_files = Set.new
        exec_result = nil

        start_markers = options[:start_markers] || []
        end_markers = options[:end_markers] || []

        syscalls = []
        process_syscall = start_markers.empty?

        Strace.run command, run_opts do |trace_file, result|
          exec_result = result

          File.open trace_file, 'r' do |trace_io|
            parser = SyscallParser.new trace_io
            parser.each do |syscall|
              if process_syscall && end_markers.any? {|em| syscall.line =~ em}
                process_syscall = false
              elsif !process_syscall && start_markers.any? {|sm| syscall.line =~ sm}
                process_syscall = true
                next
              end

              next unless process_syscall
              next if syscall.non_existing_file?

              syscalls << syscall.to_s
              log_debug $prog_name, "Syscall processed: #{syscall}"

              files = syscall.quoted_arguments
              files = files.take 1 if SINGLE_FILE_ARGUMENT_SYSCALLS.include? syscall.name
              log_debug 'strace', "Multiple access matches: '#{syscall.line}', #{files.inspect}".yellow if files.size > 1

              files.each { |f| accessed_files << File.expand_path(f) }
            end
          end
        end

        return accessed_files, exec_result, syscalls
      end
    end
  end
end