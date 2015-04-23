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
        raise_on_failure = options[:raise_on_failure].nil? || options[:raise_on_failure]
        passthrough_stdout = options[:output] == :passthrough || options[:stdout] == :passthrough
        passthrough_stderr = options[:output] == :passthrough || options[:stderr] == :passthrough

        args = options[:args] || []
        args << '-v' if $verbose && (command.start_with?('citac') || (command.start_with?('strace') && command.include?('citac')))
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

        log_debug 'exec', "Execution of '#{cmdline}' finished: #{end_time - start_time} seconds"

        if status.exitstatus == 0 || !raise_on_failure
          RunResult.new captured_output, status.exitstatus, captured_stdout, captured_stderr
        else
          raise "Command '#{cmdline}' failed with exit code #{status.exitstatus}: #{captured_output}"
        end
      end
    end
  end
end