require 'set'
require 'tmpdir'
require_relative 'parser'
require_relative 'runner'
require_relative '../../logging'

module Citac
  module Integration
    module Strace
      WRITE_SYSCALLS = %w(write writev pwrite pwritev)
      SINGLE_FILE_ARGUMENT_SYSCALLS = %w(execve readlink)

      def self.track_file_access(command, options = {})
        run_opts = options.dup
        run_opts[:syscalls] = WRITE_SYSCALLS + ['file']
        run_opts[:signals] = :none

        accessed_files = Set.new
        written_files = Set.new
        exec_result = nil

        start_markers = options[:start_markers] || []
        end_markers = options[:end_markers] || []

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

              log_debug $prog_name, syscall.line

              if WRITE_SYSCALLS.include? syscall.name
                first = syscall.file_descriptors.first
                if first
                  path = File.expand_path first
                  accessed_files << path
                  written_files << path
                end
              else
                files = syscall.quoted_arguments
                files = files.take 1 if SINGLE_FILE_ARGUMENT_SYSCALLS.include? syscall.name

                files.each { |f| accessed_files << File.expand_path(f) }

                log_debug 'strace', "Multiple access matches: '#{syscall.line}', #{files.inspect}".yellow if files.size > 1

                #TODO how to handle rename, symlink etc.? target is overwritten
                #TODO it would be safer to handle every file name of an unknown syscall as written file
              end
            end
          end
        end

        return accessed_files, written_files, exec_result
      end
    end
  end
end