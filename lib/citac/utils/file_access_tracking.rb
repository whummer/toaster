require 'set'
require 'tmpdir'
require_relative '../utils/colorize'
require_relative '../utils/exec'

module Citac
  module Utils
    module FileAccessTracking
      def self.track(command, options = {})
        Dir.mktmpdir do |dir|
          #TODO handle directories

          trace_file = File.join dir, 'trace.txt'
          strace_command = "strace -o \"#{trace_file}\" -f -e trace=file,write,writev,pwrite -e signal=none -y -qq #{command}"

          Citac::Utils::Exec.run strace_command, options

          accessed_files = Set.new
          written_files = Set.new

          syscall_exp = /\s(?<syscall>[a-z0-9_]+)\(/i
          filename_exp = /"(?'value'([^"\\]|\\.)*)"/
          write_exp = /\s((write)|(writev)|(pwrite)|(pwritev))\(\d+<(?'value'[^>]+)>/
          pipe_exp = /^pipe:\[\d+\]$/

          File.open trace_file, 'r' do |file|
            file.each_line do |line|
              line = line.strip
              next if line =~ /\)\s+=\s+-1\s+ENOENT\s/ # ignore not found files
              next if line =~ /\+\+\+\s[^+]*exit[^+]*\s\+\+\+/ # ignore exit code lines
              next if line =~ /<\.\.\.\s[a-z0-9_]+\sresumed>/ # ignore additional output of concurrently running syscalls

              syscall_match = syscall_exp.match line
              if syscall_match
                syscall = syscall_match[:syscall]

                write_matches = line.scan(write_exp)
                if write_matches.empty?
                  access_matches = line.scan(filename_exp)
                  access_matches = access_matches.take 1 if %w(execve readlink).include? syscall

                  puts "MULTIPLE ACCESS MATCHES: '#{line}', #{access_matches.inspect}".yellow if access_matches.size > 1 #TODO remove
                  access_matches.each do |accessed_file|
                    puts "PW: '#{line}'" if accessed_file[0].include?('ifconfig') || accessed_file[0].include?('hostname')
                    path = File.expand_path(accessed_file[0])
                    accessed_files << path
                    #TODO how to handle rename, symlink etc.? target is overwritten
                    #TODO it would be safer to handle every file name of an unknown syscall as written file
                  end
                else
                  puts "MULTIPLE WRITE MATCHES: '#{line}', #{write_matches.inspect}".yellow if write_matches.size > 1 #TODO remove
                  write_matches.each do |written_file|
                    unless written_file[0] =~ pipe_exp
                      path = File.expand_path(written_file[0])

                      accessed_files << path
                      written_files << path
                    end
                  end
                end
              else
                puts "Warning: Failed to parse strace line: '#{line}'".yellow
              end
            end
          end

          return accessed_files.to_a, written_files.to_a
        end
      end
    end
  end
end