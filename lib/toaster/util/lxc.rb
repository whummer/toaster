

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require 'tempfile'
require 'toaster/chef/chef_util'
require 'toaster/util/docker'
require 'toaster/util/util'
require 'toaster/util/config'
require 'toaster/util/timestamp'

module Toaster

  class LXC

    @semaphore = Mutex.new
    @lxc_init_delay = 10
    @last_init_time = 0

    LXC_ROOT_DIR = "/lxc/"

    class << self
      attr_accessor :lxc_init_delay, :last_init_time, :semaphore, :initialized
    end

    def self.new_container(prototype_name = "default", num_retries = 1)
      file = nil
      name = nil
      num = nil
      # check if the prototype with the given name exists
      existing_protos = get_prototypes_local().keys
      if !existing_protos.include?(prototype_name) &&
          !existing_protos.include?("prototype_#{prototype_name}")
        puts "WARN: Prototype with name #{prototype_name} does not exist. Existing: #{existing_protos}"
        new_proto = existing_protos[0]
        if new_proto
          new_proto = get_prototype_name(new_proto)
          puts "INFO: Using randomly chosen prototype '#{new_proto}' instead of '#{prototype_name}'."
          prototype_name = new_proto
        end
      end
      #puts "DEBUG: Thread #{Thread.current.object_id} synchronizing on semaphore #{semaphore}"
      semaphore.synchronize do

        name = get_next_container_name()
        num = get_next_container_num()
        #puts "DEBUG: Next LXC container number: #{num}. (locked on semaphore #{semaphore})"

        #
        # make sure the LXC directory and lock file is created, otherwise
        # a parallel thread might take the same container ID.
        #
        lxc_dir = "#{LXC_ROOT_DIR}/#{name}"
        lxc_lockfile = "#{LXC_ROOT_DIR}/#{name}.lock"
        puts "INFO: Creating LXC directory #{lxc_dir}"
        `mkdir -p #{lxc_dir}`
        `touch #{lxc_lockfile}`
        #puts "DEBUG: LXC directory #{lxc_dir} exists: #{File.exist?(lxc_dir)}."

        # sleep a while, if necessary...
        now = TimeStamp.now.to_i
        if (now - last_init_time) < lxc_init_delay
          time_passed = now - last_init_time
          sleep(lxc_init_delay - time_passed)
        end

        last_init_time = TimeStamp.now.to_i
      end
      #puts "DEBUG: Thread #{Thread.current.object_id} releasing semaphore #{semaphore}"

      puts "INFO: Creating new LXC container '#{name}' from prototype '#{prototype_name}'."
      key = "initLXC " + Util.generate_short_uid()
      TimeStamp.add(nil, key)
      output = `#{Util.toaster_executable} spawn "#{name}" "#{prototype_name}" 2>&1`
      TimeStamp.add(nil, key)

      ip = output.gsub("\n", " ").gsub(/.*root@(([0-9]{1,3}\.){3}[0-9]{1,3}).*/, '\1')
      if Util.is_ip_address(ip)
        puts "INFO: IP address of new LXC container '#{name}' is '#{ip}'."
      else
        puts "WARN: Cleaning up container, because output after creation was: #{output}"
        destroy_container({
          "num" => num,
          "rootdir" => "#{LXC_ROOT_DIR}/#{name}/rootfs/",
          "lxc_id" => name
        })
        if num_retries > 0
          puts "INFO: re-trying to create new LXC container after failed attempt."
          return new_container(prototype_name, num_retries - 1)
        end
      end

      return {
        "num" => num,
        "rootdir" => "#{LXC_ROOT_DIR}/#{name}/rootfs/",
        "ip" => ip,
        "lxc_id" => name,
        "creation_stdout" => output
      }
    end

    def self.copy_on_write?()
      return File.exist?("/mnt/btrfs/")
    end

    def self.prototype_container(prototype_name)
      return {
        "rootdir" => "#{LXC_ROOT_DIR}/prototype_#{prototype_name}/rootfs/",
        "lxc_id" => "prototype_#{prototype_name}"
      }
    end

    def self.exec(lxc, cmd, print_output=false, append_time_to_output=false)
      ip = lxc["ip"]
      cmd = "ssh \"#{ip}\" #{cmd}"
      output = ""
      if append_time_to_output
        output = Util.exec_with_output_timestamps(cmd)
      else
        output = `#{cmd} 2>&1`
      end
      if print_output
        puts "INFO: output of command '#{cmd}' (return code #{$?}): #{output}"
      end
      return output
    end

    def self.run_chef_node(lxc, chef_node, run_list_hash, chef_node_attrs = {})

      chef_node_name = ChefUtil.extract_node_name(chef_node)
      run_list = ChefUtil.prepare_run_list(chef_node_name, run_list_hash)

      node_attributes = { "run_list" => run_list, "toaster" => {} }
      node_attributes.merge!(chef_node_attrs)
      Config.values.each do |key,value|
        if key != "chef"
          node_attributes["toaster"][key] = value
        end
      end
      puts "DEBUG: Chef automation #{chef_node}, node attributes: #{node_attributes.inspect}"

      run_chef(lxc, chef_node, node_attributes)
    end

    def self.run_chef(lxc, chef_node, node_attributes)

      # prepare variables
      output = ""
      lxc_dir = lxc["rootdir"]
      node_file_local = Util.mktmpfile("/tmp/chef_node_")
      node_file = "#{lxc_dir}/#{node_file_local}"

      # write config files
      Util.write(node_file, node_attributes.to_json(), true)
      #puts "DEBUG: node file #{node_file} : #{File.read(node_file)}"

      

      # IMPORTANT: redirect streams from/to a stream (" < /dev/null >& /some/file"), 
      # because otherwise we might end up in a situation where the ssh command 
      # hangs and never returns, as described here:
      # http://www.snailbook.com/faq/background-jobs.auto.html
      # UPDATE: for docker.io containers under Ubuntu 13.04 this seems to 
      # be unnecessary. In fact, the workaround with piping does not work.
      out_file = "/tmp/toaster_out_#{Util.generate_short_uid()}"
      last_out_file = "/tmp/toaster_out_latest"
      cmd = "\"" +
            "toaster chefsolo #{node_file_local} " +
            # "grep -v 'FATAL: No cookbook found in' " +
            ">& #{last_out_file}; " +
            "cat #{last_out_file}; " +
            "\""
      puts "INFO: Executing command in LXC #{lxc["ip"]}: #{cmd}"
      output = exec(lxc, cmd, false, true)

      return output
    end

    def self.clean()
      if ARGV.include?("-v")
        puts "DEBUG: existing containers: #{get_container_names()}"
      end
      get_container_names().each do |lxc_name|
        puts "DEBUG: destroying LXC container #{lxc_name}"
        destroy_container(lxc_name)
      end
      Dir["#{LXC_ROOT_DIR}/lxc*"].each do |lxc_path|
        if lxc_path.match(/\.lock$/)
          # delete *.lock file
          `rm -f #{lxc_path}`
        else
          # delete LXC container directory
          if copy_on_write?()
            `/sbin/btrfs subvolume delete #{lxc_path}`
          end
          `rm -rf #{lxc_path}`
        end
      end
    end

    def self.destroy_container(lxc)
      lxc_name = lxc.kind_of?(Hash) ? lxc["lxc_id"] : lxc.to_s
      if !lxc_name.match(/[a-zA-Z0-9]+/).to_s == lxc_name
        puts "WARN: Unexpected LXC container name '#{lxc_name}'. Canceling destroy operation."
        return
      end
      `lxc-stop -n #{lxc_name} 2> /dev/null`
      `lxc-destroy -n #{lxc_name} 2> /dev/null`
      # if we are using docker, kill the container using docker...
      Toaster::Docker.kill_container(lxc_name)

       # check if copy-on-write (btrfs) is enabled
      if copy_on_write?()
        puts "DEBUG: removing previously created copy-on-write directory using btrfs: #{LXC_ROOT_DIR}/#{lxc_name}"
        `/sbin/btrfs subvolume delete #{LXC_ROOT_DIR}/#{lxc_name}`
      else
        puts "DEBUG: removing LXC directory: #{LXC_ROOT_DIR}/#{lxc_name}"
        `rm -r #{LXC_ROOT_DIR}/#{lxc_name}`
      end
      # remove lock file
      `rm -f #{LXC_ROOT_DIR}/#{lxc_name}.lock`
    end

    def self.get_next_container_name()
      return "lxc#{get_next_container_num()}"
    end
    def self.get_next_container_num()
      #next_num = get_max_container_num() + 1
      next_num = 1
      while  File.exist?("#{LXC_ROOT_DIR}/lxc#{next_num}") ||
              File.exist?("#{LXC_ROOT_DIR}/lxc#{next_num}.lock")
        next_num += 1
      end
      return next_num
    end
    def self.get_container_names()
    	result = []
    	containers = []
      containers.concat(Toaster::Docker.get_container_names())
      containers.each do |c|
        if !is_prototype?(c)
          result << c
        end
      end
      return result
    end

    def self.get_containers_for_hosts(host_machine_ips = [], include_prototypes=false)
      host_machine_ips = host_machine_ips.split(/, ;:/) if !host_machine_ips.kind_of?(Array)
      result = {}
      host_machine_ips.each do |ip|
        if ip.strip != ""
          result[ip] = get_containers_for_host(ip, include_prototypes)
        end
      end
      return result
    end

    def self.get_prototypes_for_host(host_machine_ip)
      lxcs = get_containers_for_host(host_machine_ip, true)
      lxcs.keys.dup.each do |name|
        if !get_prototype_name(name)
          lxcs.delete(name)
        end
      end
      return lxcs
    end
    def self.get_prototypes_local()
      service_port = Config.get("service.port")
      return get_prototypes_for_host("localhost:#{service_port}")
    end

    def self.new_prototype(host_machine_ip, name, os_distribution)
      require "toaster/api"
      client = ToasterAppClient.new(host_machine_ip)
      out = client.proto(name, os_distribution)
      return out
    end

    def self.get_containers_for_host(host_machine_ip, include_prototypes=false)
      out = ""
      begin
        # try connection using test service
        puts "DEBUG: Trying to connect to test service at #{host_machine_ip}"
        require "toaster/api"
        client = ToasterAppClient.new(host_machine_ip)
        out = client.lxc()
      rescue => ex
        # try connection using ssh
        puts "Unable to obtain LXC information from remote host using test service: #{ex}"

        cmd = 'sh -c \'cat #{LXC_ROOT_DIR}/*/config\''
        cmd = "ssh -o BatchMode=yes #{host_machine_ip} \" lxc-ls -l; echo \\\"__--__ \\\"; #{cmd} \""
        out = `#{cmd}`
        if !out || out.strip == "" || out.match(/Permission denied/) || 
          out.match(/No route/) || out.match(/connect/)
          raise "Connection to host #{host_machine_ip} failed: #{out}"
        end
      end

      out = out.strip
      return get_containers_from_output(out, include_prototypes)
    end

    def self.is_prototype?(name)
    	return !get_prototype_name(name).nil?
    end

    def self.get_prototype_name(name)
      name = "prototype_default" if name == "prototype"
      return nil if !name.match(/^prototype_.*/)
      return name.gsub(/^prototype_([a-zA-Z0-9_]+).*/, '\1')
    end

    private

    def self.get_containers_from_output(out, include_prototypes=false)
      result = {}

      return result if !out

      installed = []
      active = []
      lxc_out = out.split(/^__\-\-__/)[0]
      config_out = out.split(/^__\-\-__/)[1]

      return result if !out || !lxc_out || !config_out

      # output of 'lxc-ls' looks like this (installed containers in the first block, 
      # active containers in the second block):
      # 
      # total 28
      # drwxr-xr-x 2 root root 4096 Aug 14 13:53 lxc1
      # drwxr-xr-x 2 root root 4096 Aug 14 18:48 lxc2
      # ...
      # drwxr-xr-x 2 root root 0 Aug 14 13:53 lxc1
      # drwxr-xr-x 2 root root 0 Aug 14 18:48 lxc2
      # ...
      lxc_out.split(/\n/).each do |line|
        parts = line.strip.split(/\s+/)
        if parts.size == 9 && line[0] == "d"
          size = parts[4]
          name = parts[8]
          if name
            if size == "0"
              active << name
            else
              installed << name
            end
          end
        end
      end

      ips = {}
      config_out.gsub(/\n/, " ").split(/utsname\s*=\s*/).each do |cfg|
        if cfg.strip != ""
          name = cfg.gsub(/^([^\s]+)\s.*/, '\1')
          ip = cfg.gsub(/.*network\.ipv4\s*=\s*([0-9\.]+).*/, '\1')
          ips[name] = ip
          if include_prototypes && get_prototype_name(name)
            if !installed.include?(name)
              installed << name
              ips[name] = nil
            end
          end
        end
      end
      installed.each do |lxc|
        result[lxc] = {
          "state" => active.include?(lxc) ? "running" : "suspended",
          "ip" => ips[lxc]
        }
      end
      return result
    end

    def initialize
    end

  end
end
