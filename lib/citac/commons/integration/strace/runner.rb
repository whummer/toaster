require 'set'
require 'tmpdir'
require_relative '../../utils/exec'

module Citac
  module Integration
    module Strace
      def self.run(command, options = {})
        Dir.mktmpdir do |dir|
          trace_file = File.join dir, 'trace.txt'
          args = ['-o', trace_file, '-f', '-y', '-qq']

          if syscalls = options[:syscalls]
            syscalls = [syscalls] unless syscalls.respond_to? :each
            args += ['-e', "trace=#{syscalls.join(',')}"]
          end

          if signals = options[:signals]
            signals = [signals] unless signals.respond_to? :each
            args += ['-e', "signal=#{signals.join(',')}"]
          end

          command = [command] unless command.respond_to? :each
          args += command

          exec_opts = options.dup
          exec_opts[:args] = args
          exec_opts[:raise_on_failure] = false

          result = Citac::Utils::Exec.run 'strace', exec_opts

          raise "strace failed: #{result.output}" unless File.exists? trace_file

          yield trace_file, result
        end
      end
    end
  end
end