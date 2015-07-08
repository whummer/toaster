require 'open3'
require 'stringio'
require 'thread'
require_relative '../logging'
require_relative 'colorize'

module Citac
  module Utils
    module Exec
      class RunResult
        attr_reader :output, :exit_code, :stdout, :stderr

        def initialize(output, exit_code, stdout, stderr)
          @output = output
          @exit_code = exit_code
          @stdout = stdout
          @stderr = stderr
        end

        def success?
          @exit_code == 0
        end

        def failure?
          @exit_code != 0
        end

        def errors
          @output.each_line.select{|l| l =~ /error/i}.map{|l| l.strip}
        end

        def to_s
          io = StringIO.new
          io.puts @output
          io.puts "Exit code: #{@exit_code}"
          io.string
        end
      end

      def self.format_args(args)
        args.map{|a| a.to_s.gsub('"', '\"')}.map{|a| a.include?(' ') ? "\"#{a}\"" : a}.join(' ')
      end

      def self.run(command, options = {})
        verbose = $verbose && (command.start_with?('citac') || (command.start_with?('strace') && command.include?('citac')))

        raise_on_failure = options[:raise_on_failure].nil? || options[:raise_on_failure]
        passthrough_stdout = options[:output] == :passthrough || options[:stdout] == :passthrough || verbose
        passthrough_stderr = options[:output] == :passthrough || options[:stderr] == :passthrough || verbose

        args = options[:args] || []
        args << '-v' if verbose
        args = format_args args

        cmdline = "#{command} #{args}"

        log_debug 'exec', "Executing command '#{cmdline}'..."

        mutex = Mutex.new
        captured_output = ''
        captured_stdout = ''
        captured_stderr = ''

        start_time = Time.now
        status = Open3.popen3 cmdline do |stdin, stdout, stderr, wait_thr|
          thread_stdout = Thread.new do
            while line = stdout.gets
              if passthrough_stdout
                $stdout.puts line
                $stdout.flush
              end

              line = line.no_colors
              captured_stdout << line
              mutex.synchronize {captured_output << line}
            end
          end

          thread_stderr = Thread.new do
            while line = stderr.gets
              if passthrough_stderr
                $stderr.puts line
                $stderr.flush
              end

              line = line.no_colors
              captured_stderr << line
              mutex.synchronize {captured_output << line}
            end
          end

          options[:stdin].each {|line| stdin.puts line} if options[:stdin]
          stdin.close_write

          thread_stdout.join
          thread_stderr.join

          wait_thr.value
        end
        end_time = Time.now

        log_debug 'exec', "Execution of '#{cmdline}' finished (exit code = #{status.exitstatus}): #{end_time - start_time} seconds"

        if status.exitstatus == 0 || !raise_on_failure
          RunResult.new captured_output, status.exitstatus, captured_stdout, captured_stderr
        else
          raise "Command '#{cmdline}' failed with exit code #{status.exitstatus}: #{captured_output}"
        end
      end

      def self.fork(options = {})
        read_io, write_io = IO.pipe

        cpid = Kernel.fork
        if cpid == nil
          begin
            $stdout.reopen write_io
            $stderr.reopen write_io

            write_io = nil
            read_io = nil

            yield

            exit! 0
          rescue Exception => e
            if $verbose
              $stderr.puts "Fork failed: #{e.message}"
              $stderr.puts e.backtrace
            end

            exit! 1
          end
        else
          captured_output = ''
          capturer = Thread.new do
            while line = read_io.gets
              if options[:output] == :passthrough || $verbose
                $stdout.puts line
                $stdout.flush
              end

              line = line.no_colors
              captured_output << line
            end
          end

          _, status = Process.waitpid2 cpid
          exit_code = status.exitstatus

          write_io.close
          write_io = nil

          capturer.join

          return RunResult.new captured_output, exit_code, captured_output, nil
        end
      ensure
        write_io.close if write_io
        read_io.close if read_io
      end

      def self.which(executable)
        @which_cache = Hash.new unless @which_cache
        path = @which_cache[executable]

        unless path
          result = run 'which', :args => [executable], :raise_on_failure => false
          raise "Executable '#{executable}' not found in path." unless result.success?

          path = result.stdout.strip
          @which_cache[executable] = path
        end

        path
      end

      def self.which_safe(executable)
        which executable
      rescue
        nil
      end
    end
  end
end