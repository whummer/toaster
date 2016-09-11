require_relative 'syscall'
require_relative '../../logging'

module Citac
  module Integration
    module Strace
      class SyscallParser
        def initialize(trace_io)
          @trace_io = trace_io
        end

        def each
          @trace_io.rewind if @trace_io.respond_to? :rewind
          @trace_io.each do |line|
            line = line.strip
            next if line =~ /\+\+\+\s[^+]*exit[^+]*\s\+\+\+/ # ignore exit code lines
            next if line =~ /<\.\.\.\s[a-z0-9_]+\sresumed>/ # ignore additional output of concurrently running syscalls

            syscall = nil
            begin
              syscall = Syscall.new line
            rescue
              log_warn 'strace', "Failed to parse strace line: '#{line}'"
            end

            yield syscall if syscall
          end
        end
      end
    end
  end
end