require 'fileutils'

require_relative 'model'
require_relative '../docker'

module Citac
  module Environments
    class DockerEnvironmentManager
      def environments
        @envs = Citac::Docker.images.map{|i| docker_image_to_environment i}.reject{|e| e.nil?}.to_a unless @envs
        @envs
      end

      def find(os_name, os_version, spec_runner)
        env = environments.find{|e| e.os_name == os_name && e.os_version == os_version && e.spec_runners.include?(spec_runner)}
        raise "No suitable environment found for os '#{os_name}-#{os_version}' and '#{spec_runner}'" unless env

        env
      end

      def run(env, script_path)
        executable = File.executable? script_path
        FileUtils.chmod '+x', script_path unless executable

        script_name = File.basename script_path
        script_dir = File.dirname script_path

        citac_dir = '/home/oliver/Projects/citac/ruby' #TODO determine citac dir

        mounts = []
        mounts << [citac_dir, '/opt/citac', false]
        mounts << [script_dir, '/tmp/citac', true]

        output = Citac::Docker.run env.id, "/tmp/citac/#{script_name}", :mounts => mounts
        FileUtils.chmod '-x', script_path unless executable

        output
      end

      private

      def docker_image_to_environment(docker_image)
        return nil unless docker_image.name.start_with? 'citac/'

        spec_runner = docker_image.name.split('/', 2).last
        os = docker_image.tag.split '-', 2

        Environment.new docker_image.id, os.first, os.last, [spec_runner]
      end
    end
  end
end