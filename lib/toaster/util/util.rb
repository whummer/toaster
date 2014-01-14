

require 'digest/md5'
require 'socket'
require 'open4'
require 'timeout'

module Toaster
  
  #
  # Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
  #

  class Util
    # generate a UUID, for example: 550e8400-e29b-41d4-a716-446655440000
    def self.generate_uuid
      # For now, generate a pseudo-UUID here. Do not use the 'uuid' package
      # since it seems to conflict with some other gems installed on IWD instances.
      # Error message was:
      # FATAL: Gem::LoadError: Unable to activate macaddr-1.6.1, because systemu-2.2.0 conflicts with systemu (~> 2.5.0)

      uuid = rand_hex_string(16) + "-" + rand_hex_string(4) + "-" + 
        rand_hex_string(4) + "-" + rand_hex_string(4) + "-" + rand_hex_string(12)
      return uuid
    end
    def self.get_machine_id() 
      filename = File.join(get_home_dir(), ".toaster.testing.machine_id")
      return File.read(filename).strip if File.exist?(filename)
      puts "Saving machine ID to file #{filename}"
      File.open(filename, 'w') { |f| f.write(self.rand_hex_string(16)) }
      return File.read(filename).strip
    end
    def self.get_home_dir()
      user = `whoami`
      return "/root/" if user.strip == "root"
      return Dir.home
    end
    def self.generate_short_uid()
      return rand_hex_string(16)
    end
    def self.empty?(value)
      return value.nil? || (value.to_s.strip == "")
    end

    def self.file_empty?(file)
      return true if !File.exist?(file)
      return self.empty?(File.read(file))
    end

    # generate a (pseudo-)random string of a given length
    def self.rand_hex_string(length)
      return (0..length).to_a.map{|a| rand(16).to_s(16)}.join
    end

    def self.ip_address?(str)
      return is_ip_address(str)
    end

    def self.is_ip_address(str)
      return false if !str
      str = str.to_s
      m = str.match(/([0-9]{1,3}\.){3}[0-9]{1,3}/)
      m = m.nil? ? "" : m.to_s
      return (m == str)
    end

    # check if the string representation of two objects is equal
    def self.str_eql?(o1, o2)
      return "#{o1}" == "#{o2}"
    end

    # compute the MD5 hash of a given string or file
    def self.md5(str_or_file, read_from_file = false)
      if read_from_file
        return nil if !File.exist?(str_or_file)
        file = File.expand_path(str_or_file)
        md5 = `md5sum #{file}`
        md5.gsub!(/^([a-zA-Z0-9]+) .*/,'\1')
        return md5
      end
      return Digest::MD5.hexdigest(str_or_file)
    end

    def self.project_root_dir()
      return File.expand_path(File.join(File.dirname(__FILE__), "..", "..", ".."))
    end

    def self.toaster_executable()
      return File.join(project_root_dir(), "bin", "toaster")
    end

    # compute the MD5 hash over the contents of a given file
    def self.file_md5(file)
      return md5(file, true)
    end

    def self.write(file, content, overwrite=false)
      if !overwrite && File.exist?(file)
        raise "File exists and no overwrite option provided: #{file}"
      end
      File.open(file, 'w') {|f| f.write(content) }
    end

    #return local IP address
    def self.ipaddress()
      # turn off reverse DNS resolution temporarily
      orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
      ip = nil
      begin
        UDPSocket.open do |s|
          s.connect '8.8.8.8', 1
          ip = s.addr.last
        end
      ensure
        Socket.do_not_reverse_lookup = orig
      end
      puts "IP: #{ip}"
      if !is_ip_address(ip)
        # TODO: IP lookup using ifconfig...
      end
      return ip
    end

    

    def self.print_backtrace(ex, max_lines = -1, start_line = 0)
      puts "#{ex}\n#{ex.backtrace[start_line..max_lines].join("\n")}\n..."
    end

    def self.match_any(str, pattern_list=[".*"])
      pattern_list.each do |p|
        return true if str.match(/#{p}/)
      end
      return false
    end

    def self.pid()
      return Process.pid
    end

    def self.child_process_pids()
      pid = Process.pid
      child_pids = `ps o pid= --ppid #{pid}`
      status = $?
      result = child_pids.strip.split(/\s+/)
      # the PID of the forked "ps" process is usually also 
      # part of this list, hence remove it from the result
      result.delete("#{status.pid}")
      return result
    end

    # based on:
    # http://www.ruby-doc.org/stdlib-1.9.3/libdoc/timeout/rdoc/Timeout.html
    # added: functionality to kill external forked processes on timeout
    def self.exec_timeout(sec=10*60, klass=nil, kill_forked_processes=true, &block)
      return yield(sec) if sec == nil or sec.zero?
      exception = klass || Class.new(Timeout::ExitException)

      children_before = child_process_pids()

      begin
        begin
          x = Thread.current
          y = Thread.start {
            begin
              sleep sec
            rescue => e
              x.raise e
            else

              # terminate all sub-processes
              # forked by the block execution
              if kill_forked_processes
                puts "DEBUG: child processes before task execution: #{children_before}"
                children_after = child_process_pids()
                puts "DEBUG: child processes during task execution, after timeout (#{sec}sec): #{children_after}"
                diff = children_after - children_before
                puts "INFO: Killing forked subprocesses: #{diff}" if !diff.empty?
                diff.each do |kill_pid|
                  puts "DEBUG: Command of process #{kill_pid}: '#{get_process_details(kill_pid)['cmd']}'"
                end
                kill_processes(diff)
              end

              x.raise exception, "execution expired"
            end
          }
          return yield(sec)
        ensure
          if y
            y.kill
            y.join # make sure y is dead.
          end
        end
      rescue exception => e
        rej = /\A#{Regexp.quote(__FILE__)}:#{__LINE__-4}\z/
        (bt = e.backtrace).reject! {|m| rej =~ m}
        level = -caller(Timeout::CALLER_OFFSET).size
        while Timeout::THIS_FILE =~ bt[level]
          bt.delete_at(level)
          level += 1
        end
        raise if klass            # if exception class is specified, it
                                  # would be expected outside.
        raise RuntimeError, e.message, e.backtrace
      end
    end

    def self.build_file_hash_for_ohai(paths, hash_to_fill = nil)
      files = hash_to_fill ? hash_to_fill : {}
      paths.each do |path|
        if File.exist?(path)
          fileObj = File.new(path)
          statObj = File::Stat.new(path)
          files[path] = {
            "mode" => statObj.mode,
            "bytes" => fileObj.size,
            "ctime" => fileObj.ctime.to_i,
            "mtime" => fileObj.mtime.to_i,
            "owner" => "#{statObj.uid}:#{statObj.gid}"
          }
          if File.symlink?(path)
            files[path]["symlink_to"] = File.readlink(path)
          end
          if File.directory?(path)
            entries = Dir.entries(path).size - 2
            entries = 0 if entries < 0
            entries_rec = -1
            if path != "" && !path.match(/^\/+((dev)|(etc)|(lib)|(lib32)|(lib64)|(proc)|(opt)|(run)|(sys)|(usr)|(var))\/*$/)
              # find number of descendants (recursively)
              entries_rec = `find #{path} | wc -l`.strip
            end
            files[path]["type"] = "dir"
            files[path]["num_entries"] = entries
            files[path]["entries_recursive"] = entries_rec
          else
            md5 = Toaster::Util.file_md5(path)
            files[path]["hash"] = md5.strip if md5
          end
        else
          # nil indicates that the file does not exist..
          files[path] = nil
        end
      end
      return files
    end

    def self.diff_dirs(dir1, dir2)
      require "diffy"
      out = "<style type=\"text/css\">" +
            ".diff_dir .content { border: 1px solid #999999; padding: 3px; }\n" +
            ".changed, .changed a { color: #000000; }\n" +
            ".not_changed, .not_changed a { color: #999999; }\n" +
            ".filename a { cursor: pointer; text-decoration: underline; }\n" +
            "</style>" +
            "<ul class=\"diff_dir\">"
      files = Set.new
      files.merge(`find #{dir1}/ -printf '%P\n'`.strip.split("\n"))
      files.merge(`find #{dir2}/ -printf '%P\n'`.strip.split("\n"))
      files.delete("")
      files.each_with_index do |file,idx|
        f1 = "#{dir1}/#{file}"
        f2 = "#{dir2}/#{file}"
        if !File.directory?(f1) && !File.directory?(f2)
          tmp_files = []
          if !File.exist?(f1)
            `mkdir -p '#{File.dirname(f1)}'`
            write(f1, "")
            tmp_files << f1
          end
          if !File.exist?(f2)
            `mkdir -p '#{File.dirname(f2)}'`
            write(f2, "")
            tmp_files << f2
          end
          begin
            thediff = ::Diffy::Diff.new(f1, f2, :source => 'files').to_s(:html)
            changed = thediff.include?("class=\"del\"") || thediff.include?("class=\"ins\"")
            out += "<li class=\"file #{changed ? 'changed' : 'not_changed'}\" id=\"diff_file_#{idx}\">"
            out += "<div class=\"filename\">" +
              "<a onclick=\"$('#diff_file_#{idx} .content').toggle('blind', {}, 50);\">#{file}</a></div>"
            out += "<div class=\"content\">"
            out += thediff
            out += "</div></li>"
          rescue => e
            out += "Cannot create diff: #{e}\n"
          end
          tmp_files.each do |file|
            File.delete(file)
          end
        end
      end
      out += "</ul>"
      return out
    end

    def self.kill_processes(pids)
      pids = [pids] if !pids.kind_of?(Array)
      pids.each do |pid|
        kill(pid)
      end
    end

    def self.kill(pid)
      `kill #{pid}`
      max_wait = 5
      (1..max_wait).each do
        if !process_alive?(pid)
          return
        end
        sleep 1
      end
      # process is still alive --> kill with SIGKILL
      `kill -sigkill #{pid}`
    end

    def self.process_alive?(pid)
      `ps --pid #{pid}`
      code = $?
      return code.exitstatus == 0
    end

    def self.get_process_details(pid)
      cmd = `ps o cmd= --pid #{pid}`.strip
      return {
        "cmd" => cmd
      }
    end

    def self.exec_in_parallel(collection, &block) 
      num_threads = 0
      result_queue = Queue.new
      results = []
      collection.each do |c|
        num_threads += 1
        Thread.start {
          begin 
            result_queue << block.call(c)
          rescue Object => ex
            result_queue << ex
          end
        }
      end
      (1..num_threads).each do
        results << result_queue.pop
      end
      return results
    end

    def self.exec_with_output_timestamps(cmd)
      pid, stdin, stdout, stderr = Open4::popen4(cmd)
      start_time = Time.now.to_f
      last_time = start_time
      output = ""
      stdout.each_line do |line|
        now = Time.now.to_f
        diff1 = now - start_time
        diff2 = now - last_time
        last_time = now
        output += "[#{'%.3f' % diff1},#{'%.4f' % diff2}] #{line}"
      end
      return output
    end

    def self.mktmpfile(relative_to="/tmp/", &block)
      name = ""
      begin
        name = `mktemp`.strip
        File.delete(name) if File.exist?(name)
        name = File.basename(name)
        name = "#{relative_to}#{name}"
      end while File.exist?(name)
      # we have determined the file name. now run the block.
      `touch #{name}`
      if block
        begin
          block.call(name)
        ensure
          File.delete(name)
        end
      else 
        return name
      end
    end

    # Dir.mktmpdir fails under certain JRuby versions, hence we 
    # provide our own simple implementation here..
    # see, e.g., http://jira.codehaus.org/browse/JRUBY-6178
    def self.mktmpdir(&block)
      file = Tempfile.new('toaster_tmp_dir')
      path = file.path
      file.unlink
      Dir.mkdir(path)
      begin
        block.call(path)
      ensure
        FileUtils.rm_rf(path)
      end
    end

    def self.starts_with?(string, prefix)
      prefix = prefix.to_s
      string[0, prefix.length] == prefix
    end

    def self.latest_timestamp_item(list, pattern)
      latest = 0
      latest_item = nil
      list.each do |item|
        if item.to_s.match(pattern).to_s == item.to_s
          time = item.to_s.gsub(pattern, '\1')
          time = time.to_f
          if time > latest
            latest = time
            latest_item = item
          end
        end
      end
      return latest_item
    end

    def self.latest_timestamp(list, pattern)
      latest = 0
      list.each do |item|
        if item.to_s.match(pattern).to_s == item.to_s
          time = item.to_s.gsub(pattern, '\1')
          time = time.to_f
          if time > latest
            latest = time
          end
        end
      end
      return latest
    end

  end
end
