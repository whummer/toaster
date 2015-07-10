require 'fileutils'

require_relative 'common'
require_relative '../config'
require_relative '../../commons/model'
require_relative '../../commons/integration/docker'
require_relative '../../commons/integration/sysctl'
require_relative '../../commons/utils/colorize'
require_relative '../../commons/utils/exec'
require_relative '../../commons/logging'

module Citac
  module Environments
    class DockerEnvironmentManager
      include EnvironmentManagerExtensions

      def setup(options = {})
        puts 'Building docker images...'
        setup_images options

        puts 'Setting up strace permissions...'
        setup_strace_permissions
      end

      def setup_images(options = {})
        image_dir = File.join Citac::Config.base_dir, 'ext', 'docker', 'images'
        Dir.entries(image_dir).select{|d| File.directory?(File.join(image_dir, d))}.sort.each do |type_dir|
          next if type_dir == '.' || type_dir == '..'

          type, subject = type_dir.split '-', 2
          Dir.entries(File.join(image_dir, type_dir)).each do |os_dir|
            next if os_dir == '.' || os_dir == '..'

            name = "citac_#{type}/#{subject}:#{os_dir}"
            dir = File.join image_dir, type_dir, os_dir

            puts "Setting up image '#{name}'...".yellow
            exec_opts = options.dup
            exec_opts[:args] = ['-t', name, dir]
            exec_opts[:raise_on_failure] = false

            result = Citac::Utils::Exec.run 'docker build', exec_opts
            if result.success?
              puts 'OK'.green
            else
              puts 'FAIL'.red
              puts result.output
              return
            end
          end
        end
      end

      def setup_strace_permissions
        return if @setup_strace_permissions_done
        @setup_strace_permissions_done = true

        log_debug $prog_name, 'Checking if tracing is restricted to child processes...'
        ptrace_scope = Citac::Integration::Sysctl.get_param 'kernel.yama.ptrace_scope'
        unless ptrace_scope.nil? || ptrace_scope == '0'
          puts 'Tracing is currently configured to only be allowed on child processes.'.yellow
          puts 'Configuring kernel to allow tracing any process of the same user...'

          Citac::Integration::Sysctl.set_param 'kernel.yama.ptrace_scope', '0'
        end

        log_debug $prog_name, 'Checking if tracing is allowed within docker dontainers...'
        env = environments.first
        result = Citac::Integration::Docker.run env.id, %w(strace true), :raise_on_failure => false
        unless result.success?
          puts 'Tracing is currently not allowed within docker containers.'.yellow
          puts 'Configuring apparmor to allow tracing...'

          Citac::Utils::Exec.run 'aa-complain', :args => ['/etc/apparmor.d/docker']
        end
      end

      def environments
        @envs ||= Citac::Integration::Docker.images.map{|i| docker_image_to_environment i}.select{|e| e}
      end

      def run(env, script_path, options = {})
        setup_strace_permissions

        cleanup_instance = options[:cleanup_instance].nil? || options[:cleanup_instance]
        executable = File.executable? script_path
        FileUtils.chmod '+x', script_path unless executable

        script_name = File.basename script_path
        script_dir = File.dirname script_path

        mounts = []
        mounts << [Citac::Config.base_dir, '/opt/citac', false]
        mounts << [Citac::Utils::Exec.which('docker'), '/usr/bin/docker', false]
        mounts << ['/var/run/docker.sock', '/var/run/docker.sock', false]
        mounts << [script_dir, '/tmp/citac', true]

        if env.operating_system.name == 'debian' || env.operating_system.name == 'ubuntu'
          locale = 'C.UTF-8'
        elsif env.operating_system.name == 'centos'
          locale = 'en_US.utf8'
        else
          locale = nil
        end

        env_id = env.respond_to?(:id) ? env.id : env.to_s
        output = Citac::Integration::Docker.run env_id, "/tmp/citac/#{script_name}",
                                   :mounts => mounts,
                                   :locale => locale,
                                   :output => options[:output],
                                   :raise_on_failure => options[:raise_on_failure],
                                   :keep_container => !cleanup_instance

        FileUtils.chmod '-x', script_path unless executable

        Citac::Model::EnvironmentInstance.new output.container_id, env, output
      end

      def commit(instance, env)
        instance_id = instance.respond_to?(:id) ? instance.id : instance.to_s
        Citac::Integration::Docker.commit instance_id, "citac_environments/#{env.spec_runners.first}", env.operating_system.to_s
      end

      def cleanup(instance)
        instance_id = instance.respond_to?(:id) ? instance.id : instance.to_s
        Citac::Integration::Docker.remove instance_id
      end

      def cache_directory
        Citac::Config.cache_dir
      end

      def cache_enabled?
        Citac::Integration::Docker.container_running? 'citac-service-cache'
      end

      def enable_caching
        return if cache_enabled?

        Citac::Integration::Docker.remove 'citac-service-cache', :raise_on_failure => false

        FileUtils.makedirs cache_directory unless Dir.exists? cache_directory
        mounts = [[cache_directory, '/var/citac/cache', true]]

        Citac::Utils::Exec.run 'iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to 3128 -w'
        Citac::Integration::Docker.start_daemon 'citac_services/cache:squid', nil, :network => :host, :mounts => mounts, :name => 'citac-service-cache'
      rescue StandardError => e
        raise "Setting up caching failed. Root privileges are required.#{$/}#{e}"
      end

      def disable_caching
        if cache_enabled?
          Citac::Utils::Exec.run 'iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to 3128 -w'
          Citac::Integration::Docker.stop 'citac-service-cache'
          Citac::Integration::Docker.remove 'citac-service-cache'
        end
      rescue StandardError => e
        raise "Tearing down caching failed. Root privileges are required.#{$/}#{e}"
      end

      def clear_cache
        enabled = cache_enabled?
        disable_caching if enabled

        FileUtils.rm_rf cache_directory
        FileUtils.makedirs cache_directory
        FileUtils.chmod 0777, cache_directory

        enable_caching if enabled
      end

      def cache_last_accessed_resources(count)
        if cache_enabled?
          result = Citac::Utils::Exec.run 'docker exec citac-service-cache tail -n', :args => [count, '/var/log/squid3/access.log']
          result.output.lines
        else
          []
        end
      end

      def cache_stream_accessed_resources(count)
        if cache_enabled?
          opts = {:args => [count, '/var/log/squid3/access.log'], :output => :passthrough}
          begin
            Citac::Utils::Exec.run 'docker exec citac-service-cache tail -f -n', opts
          rescue Interrupt
            # ignore interrupt
          end
        else
          raise 'Cache is not enabled'
        end
      end

      private

      def docker_image_to_environment(docker_image)
        return nil unless docker_image.name.start_with? 'citac_environments/'
        return nil if docker_image.name == 'citac_environments/base'

        spec_runner = docker_image.name.split('/', 2).last
        os = Citac::Model::OperatingSystem.parse docker_image.tag

        Citac::Model::Environment.new docker_image.id, os, [spec_runner]
      end
    end
  end
end