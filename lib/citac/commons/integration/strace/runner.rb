require 'set'
require 'tmpdir'
require_relative '../../utils/exec'
require_relative '../../logging'

module Citac
  module Integration
    module Strace
      def self.get_args(trace_file, options = {})
        args = ['-o', trace_file, '-qq']
        args << '-f' unless options[:no_follow]

        if syscalls = options[:syscalls]
          syscalls = [syscalls] unless syscalls.respond_to? :each
          args += ['-e', "trace=#{syscalls.join(',')}"]
        end

        if signals = options[:signals]
          signals = [signals] unless signals.respond_to? :each
          args += ['-e', "signal=#{signals.join(',')}"]
        end

        args
      end

      def self.run(command, options = {})
        Dir.mktmpdir do |dir|
          trace_file = File.join dir, 'trace.txt'
          command = [command] unless command.respond_to? :each

          args = get_args trace_file, options
          args += command

          exec_opts = options.dup
          exec_opts[:args] = args
          exec_opts[:raise_on_failure] = false

          result = Citac::Utils::Exec.run 'strace', exec_opts

          raise "strace failed: #{result.output}" unless File.exists? trace_file

          yield trace_file, result
        end
      end

      def self.attach(trace_file, options = {})
        File.delete trace_file if File.exists? trace_file

        Dir.mktmpdir do |dir|
          outfile = File.join dir, 'strace.stdout'
          errfile = File.join dir, 'strace.stderr'

          args = get_args trace_file, options
          args += ['-p', Process.pid]

          cmdline = "strace #{Citac::Utils::Exec.format_args(args)}"
          log_debug 'strace', "Attaching strace with command '#{cmdline}'..."

          strace_pid = spawn cmdline, :out => outfile, :err => errfile
          waitthread = Thread.new { Process.waitpid2 strace_pid }

          sleep 0.1 until File.exists?(trace_file) || !waitthread.alive?
          sleep 0.1

          unless waitthread.alive?
            strace_output = IO.read(outfile).strip + IO.read(errfile).strip
            raise "strace failed: #{strace_output}"
          end

          begin
            File.exists? 'CITAC_STRACE_ATTACH_START_MARKER'

            yield
          ensure
            File.exists? 'CITAC_STRACE_ATTACH_END_MARKER'

            Process.kill 'SIGINT', strace_pid if waitthread.alive?

            _, status = waitthread.value
            strace_output = IO.read(outfile).strip + IO.read(errfile).strip

            raise "strace failed: #{strace_output}" if status.exitstatus != 0 || strace_output.size != 0

            start_marker_found = false
            end_marker_found = false

            File.open trace_file do |f|
              f.each do |line|
                start_marker_found = true if line.include? 'CITAC_STRACE_ATTACH_START_MARKER'
                end_marker_found = true if line.include? 'CITAC_STRACE_ATTACH_END_MARKER'
              end
            end

            raise 'strace attach: start marker not found in trace file' unless start_marker_found
            raise 'strace attach: end marker not found in trace file' unless end_marker_found
          end
        end
      end
    end
  end
end