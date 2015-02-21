require 'fileutils'

require_relative 'common'
require_relative '../model'
require_relative '../docker'

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

        citac_dir = '/home/oliver/Projects/citac/ruby' #TODO determine citac dir

        mounts = []
        mounts << [citac_dir, '/opt/citac', false]
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
        Citac::Docker.commit instance_id, "citac/#{env.spec_runners.first}", env.operating_system.to_s
      end

      private

      def docker_image_to_environment(docker_image)
        return nil unless docker_image.name.start_with? 'citac/'

        spec_runner = docker_image.name.split('/', 2).last
        os = Citac::Model::OperatingSystem.parse docker_image.tag

        Citac::Model::Environment.new docker_image.id, os, [spec_runner]
      end
    end
  end
end