
#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/state/transition_edge"
require "toaster/markup/markup_util"
require "toaster/state/ptrace_util"
require "pty"

include Toaster

module Toaster

  class SyscallTracer

    FILE_DUMPSTATE = "/tmp/tracer.dumpstate"
    FILE_STATEDUMP = "/tmp/tracer.state.dump"
    FILE_TMPDIR = "/tmp/tracer.tmp.dir"
    FILE_ACKS = "/tmp/tracer.acks"

    def initialize()
      # type 0 syscalls (see below for parsing)
      @syscalls_0 = ["open", "write", "openat"]
      # type 1 syscalls (see below for parsing)
      @syscalls_1 = ["creat", "mkdir", "rmdir", "link", "unlink", "symlink", 
        "chown", "lchown", "chmod"]
      # type 2 syscalls (see below for parsing)
      @syscalls_2 = ["rename", "unlinkat", "mkdirat", "fchownat", "mknodat"]
      # type 3 syscalls (see below for parsing)
      @syscalls_3 = ["fchmod", "fchown"]
      # type 4 syscalls (see below for parsing)
      @syscalls_4 = ["utimensat"]
      @acked_syscalls = @syscalls_0.concat(@syscalls_1).concat(@syscalls_2).concat(@syscalls_3).concat(@syscalls_4)
      @monitored_syscalls = @acked_syscalls.dup.concat(["open", "openat", "chdir"]) #, "close", "dup", "dup2", "dup3"
      @grep_cmd = "ps aux | grep -v grep | grep -v bash | grep -v screen | grep -v SCREEN | grep strace | grep #{Process.pid}"
      @pwd_map = {}
      @num_acks_sent = 0
      @num_acks_received = 0
      @execution_prestate = {"files"=>{}}
    end

    def dump_execution_prestate
      Util.write(FILE_DUMPSTATE, "1", true)

      # HACK: this causes a syscall which initiates the dump further below..
      Dir.mkdir(FILE_TMPDIR)
      Dir.rmdir(FILE_TMPDIR)

      state = File.read(FILE_STATEDUMP)
      if state.strip == ""
        puts "WARN: could not read pre-state dump from #{FILE_STATEDUMP}"
        return {}
      else
        return MarkupUtil.parse_json(state)
      end
    end

    def start()

      #puts "INFO: writing values to #{FILE_ACKS}"
      `echo ":#{@acked_syscalls.join(':')}:" > #{FILE_ACKS}`
      @monitoring_active = true

      `echo "" > #{FILE_DUMPSTATE}`
      `echo "" > #{FILE_STATEDUMP}`

      # start strace process
      do_start_process = true
      do_start_thread = false

      if do_start_process

        tracer_pid = start_strace()

        if do_start_thread
          __legacy_start_thread()
        end

      else
        __legacy_ruby_ptrace()
      end

    end

    def stop()
      puts "DEBUG: writing empty string to #{FILE_ACKS}"
      `echo "" > #{FILE_ACKS}`
      @monitoring_active = false
    end

    def parse_line(line)
      pwd_map = @pwd_map
      if is_correct_strace_line(line)

        syscall = extract_syscall(line)
        syscall_pid = extract_pid(line)
        if !pwd_map[syscall_pid]
          # get initial pwd for the process which does the syscall
          pwd_map[syscall_pid] = get_pwd_for_pid(syscall_pid)
        end
        pwd = pwd_map[syscall_pid]
        if syscall == "chdir"
          pwd = pwd_map[syscall_pid] = get_pwd_for_pid(syscall_pid)
        elsif syscall == "write"
          if line.match(/.*write\([0-9]+<(.*)>.*/)
            mod_file = line.gsub(/.*write\([0-9]+<(.*)>.*/, '\1').strip
            return report_file(mod_file, pwd)
          elsif line.match(/.*write\([0-9]+,.*/)
            fd = line.gsub(/.*write\(([0-9]+),.*/, '\1').strip
            mod_file = PtraceUtil.get_filename_for_fd(syscall_pid, fd)
            return report_file(mod_file, pwd)
          end
        elsif syscall == "open" || syscall == "openat"
          if  line.match(/O_WRONLY/) ||
              line.match(/O_RDWR/) ||
              line.match(/O_APPEND/) ||
              line.match(/O_CREAT/)
            if syscall == "open"
              mod_file = line.gsub(/.*open\("([^"]+)".*/, '\1').strip
              return report_file(mod_file, pwd)
            elsif syscall == "openat"
              if line.match(/.*openat\(AT_FDCWD,\s*"([^"]+)".*/)
                mod_file = line.gsub(/.*openat\(AT_FDCWD,\s*"([^"]+)".*/, '\1').strip
                return report_file(mod_file, pwd)
              elsif line.match(/.*openat\([0-9]+,\s*"([^"]+)".*/)
                fd = line.gsub(/.*openat\(([0-9]+),\s*"[^"]+".*/, '\1').strip.to_i
                mod_file = PtraceUtil.get_filename_for_fd(syscall_pid, fd)
                return report_file(mod_file, pwd)
              elsif line.match(/.*openat\("([^"]+)",\s*"[^"]+".*/)
                mod_file = line.gsub(/.*openat\("([^"]+)",\s*"[^"]+".*/, '\1').strip
                return report_file(mod_file, pwd)
              end
            end
          end
        else

          if @syscalls_1.include?(syscall)
            mod_file = line.gsub(/.*((#{@syscalls_1.join(')|(')}))\("([^"]+)".*/, "\\#{@syscalls_1.size + 2}").strip
            return report_file(mod_file, pwd)
          end
          if @syscalls_2.include?(syscall)
            mod_file = line.gsub(/.*((#{@syscalls_2.join(')|(')}))\([^,]+,\s*"([^"]+)".*/, "\\#{@syscalls_2.size + 2}").strip
            return report_file(mod_file, pwd)
          end
          if @syscalls_3.include?(syscall)
            fd = line.gsub(/.*((#{@syscalls_3.join(')|(')}))\(([^,]+),.*/, "\\#{@syscalls_3.size + 2}").strip.to_i
            mod_file = PtraceUtil.get_filename_for_fd(syscall_pid, fd)
            #puts "!! syscalls_3: #{mod_file}"
            return report_file(mod_file, pwd)
          end
          if @syscalls_4.include?(syscall)
            mod_file = nil
            pattern1 = ".*((#{@syscalls_4.join(')|(')}))\\(([0-9]+),.*"
            pattern2 = ".*((#{@syscalls_4.join(')|(')}))\\([^,]+,\\s*\"([^\"]+)\".*"
            if line.match(/#{pattern1}/)
              fd = line.gsub(/#{pattern1}/, "\\#{@syscalls_4.size + 2}").strip.to_i
              mod_file = PtraceUtil.get_filename_for_fd(syscall_pid, fd)
            elsif line.match(/#{pattern2}/)
              mod_file = line.gsub(/#{pattern2}/, "\\#{@syscalls_4.size + 2}")
            end
            #puts "!! syscalls_3: #{mod_file}"
            return report_file(mod_file, pwd)
          end

        end

      end
      return nil
    end

    def is_correct_strace_line(line)
      line.match(/^(\[pid\s+)?[0-9]+\]?\s+[a-zA-Z0-2]+\(.*/)
    end
    def extract_syscall(line)
      line.gsub(/^(\[pid\s+)?[0-9]+\]?\s+([a-zA-Z0-2]+)\(.*/, '\2').strip
    end
    def extract_pid(line)
      line.gsub(/^(\[pid\s+)?([0-9]+)\]?\s+([a-zA-Z0-2]+)\(.*/, '\2').strip
    end

    def report_file(mod_file, pwd)
      if !mod_file || mod_file.to_s.strip == ""
        return
      end
      if  !mod_file.match(/pipe:.*/) && 
          !mod_file.match(/socket:.*/) && 
          !mod_file.match(/\/dev\/.*/) &&
          !mod_file.match(/\/proc\/.*/) && 
          !mod_file.match(/\/tmp\/chef-script.*/) && 
          !mod_file.match(/\/var\/chef\/cache\/.*/) && 
          !mod_file.match(/\/tmp\/tracer\.acks.*/)
        if is_correct_strace_line(mod_file)
          puts "WARN: Apparently could not parse syscall line from strace: #{mod_file}"
          return
        end
        #puts "=====> #{pwd} - #{mod_file}"
        if mod_file[0] != "/" && pwd != ""
          mod_file = "#{pwd}/#{mod_file}"
        end
        # ignore /tmp files
        if !mod_file.match(/^\/tmp\//)
          return mod_file
        end
        return nil
      end
    end

    private

    def start_strace()

      tracer_pid = get_tracer_pid()
      if tracer_pid == ""
        # Start monitoring process in background
        exec_dir = File.join(File.dirname(File.expand_path(__FILE__)), 
            "..", "..", "..", "bin", "strace-4.8_patched")
        to_exec = nil
        if (/x86_64/ =~ RUBY_PLATFORM) != nil
          to_exec = "#{exec_dir}/strace-x86_64"
        elsif (/i686/ =~ RUBY_PLATFORM) != nil
          to_exec = "#{exec_dir}/strace-i686"
        else
          emsg = "Unsupported platform or CPU architecture (no strace binary available): #{RUBY_PLATFORM}"
          puts "WARN: #{emsg}"
          throw emsg
        end
        tracer_cmd = "#{to_exec} -p #{Process.pid} -f -e #{@monitored_syscalls.join(',')} -s 0"

        if File.exist?(to_exec)
          puts "INFO: Start monitoring process in background: #{tracer_cmd}"
          fork_pid = Process.fork do
            PTY.spawn( tracer_cmd ) do |stdout, stdin, pid|
              begin
                stdout.each { |line|
                  #puts ": #{line}"
  
                  # write prestate dump to file if requested..
                  if File.read(FILE_DUMPSTATE).strip == "1"
                    puts "INFO: dumping state to file #{FILE_STATEDUMP}.."
                    #puts "DEBUG: this syscall: #{line}"
                    Util.write(FILE_STATEDUMP, MarkupUtil.to_json(@execution_prestate), true)
                    @execution_prestate = {"files" => {}}
                    Util.write(FILE_DUMPSTATE, "0", true)
                  end
  
                  begin
                    if line.match(/waiting for ack for syscall/)
                      #puts "sending ACK for syscall: #{line}"
                      stdin.puts("y")
                      @num_acks_sent += 1
                      #puts "num_acks_sent: #{@num_acks_sent}" if (@num_acks_sent % 100 == 0)
                    elsif line.match(/got ack for syscall/)
                      @num_acks_received += 1
                      #puts "num_acks_received: #{@num_acks_received}" if @num_acks_received % 100 == 0
                    else
                      if @monitoring_active
                        mod_file = parse_line(line)
                        if mod_file
                          #puts "=====> #{mod_file}"
                          if !@execution_prestate["files"].include?(mod_file) # don't overwrite previous state info!
                            Util.build_file_hash_for_ohai([mod_file], @execution_prestate["files"])
                          end
                        end
                      end
                    end
  
                  rescue => exc
                    puts "WARN: Exception in strace processing: #{exc} - #{exc.backtrace.join("\n")}"
                  end
                }
              rescue Errno::EIO
                # swallow - this probably just means that the process has finished giving output"
              end
              puts "INFO: Strace process terminating..."
            end
          end

        else

          puts "WARN: Cannot find patched strace executable: #{tracer_cmd}"

        end

      end
      tracer_pid = get_tracer_pid()
      return tracer_pid
    end

    def kill_tracer_process()
      pid = get_tracer_pid()
      if pid && pid != ""
        `kill #{pid}`
      end
    end

    def get_tracer_pid()
      tracer_pid = `#{@grep_cmd}`
      #puts "grepping for strace - output: #{tracer_pid}"
      tracer_pid = tracer_pid.gsub(/[^\s]+\s+([^\s]+)\s+.*/, '\1').strip
      return tracer_pid
    end

    def get_pwd_for_pid(pid)
      dir = `pwdx #{pid} 2> /dev/null`
      dir = dir.gsub(/[0-9]*:\s+(.*)/, '\1').strip
      if dir != ""
        return dir
      end
      #puts "WARN: Unknown pwd for process #{pid}, fallback to '#{Dir.pwd}'"
      # fallback to pwd
      return Dir.pwd
    end

  end

end
