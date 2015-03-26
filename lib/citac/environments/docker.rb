require 'fileutils'

require_relative 'common'
require_relative '../config'
require_relative '../model'
require_relative '../docker'
require_relative '../utils/exec'

module Citac
  module Environments
    class DockerEnvironmentManager
      include EnvironmentManagerExtensions

      def environments
        @envs = Citac::Docker.images.map{|i| docker_image_to_environment i}.reject{|e| e.nil?}.to_a unless @envs
        @envs
      end

      def run(env, script_path, options = {})
        cleanup_instance = options[:cleanup_instance].nil? || options[:cleanup_instance]
        executable = File.executable? script_path
        FileUtils.chmod '+x', script_path unless executable

        script_name = File.basename script_path
        script_dir = File.dirname script_path

        mounts = []
        mounts << [Citac::Config.base_dir, '/opt/citac', false]
        mounts << ['/var/run/docker.sock', '/var/run/docker.sock', false]
        mounts << [script_dir, '/tmp/citac', true]

        env_id = env.respond_to?(:id) ? env.id : env.to_s
        output = Citac::Docker.run env_id, "/tmp/citac/#{script_name}",
                                   :mounts => mounts,
                                   :output => options[:output],
                                   :raise_on_failure => options[:raise_on_failure],
                                   :keep_container => !cleanup_instance

        FileUtils.chmod '-x', script_path unless executable

        Citac::Model::EnvironmentInstance.new output.container_id, env, output
      end

      def commit(instance, env)
        instance_id = instance.respond_to?(:id) ? instance.id : instance.to_s
        Citac::Docker.commit instance_id, "citac_environments/#{env.spec_runners.first}", env.operating_system.to_s
      end

      def cleanup(instance)
        instance_id = instance.respond_to?(:id) ? instance.id : instance.to_s
        Citac::Docker.remove instance_id
      end

      def cache_directory
        Citac::Config.cache_dir
      end

      def cache_enabled?
        Citac::Docker.container_running? 'citac-service-cache'
      end

      def enable_caching
        mounts = [[cache_directory, '/var/citac/cache', true]]

        Citac::Utils::Exec.run 'iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to 3128 -w'
        Citac::Docker.start_daemon 'citac_services/cache:squid', nil, :network => :host, :mounts => mounts, :name => 'citac-service-cache'
      rescue StandardError => e
        raise "Setting up caching failed. Root privileges are required.#{$/}#{e}"
      end

      def disable_caching
        if cache_enabled?
          Citac::Utils::Exec.run 'iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to 3128 -w'
          Citac::Docker.stop 'citac-service-cache'
          Citac::Docker.remove 'citac-service-cache'
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