require_relative '../utils/exec'

module Citac
  module Docker
    class DockerRunResult < Citac::Utils::Exec::RunResult
      attr_reader :container_id

      def initialize(output, exit_code, container_id)
        super output, exit_code
        @container_id = container_id
      end
    end

    def self.start_daemon(image, command = nil, options = {})
      image_id = image.respond_to?(:id) ? image.id : image.to_s

      parameters = ['-d']
      parameters += ['--net', options[:network].to_s] if options[:network]
      parameters += mounts_to_parameters options[:mounts] if options[:mounts]
      parameters << image_id
      parameters << command if command

      result = Citac::Utils::Exec.run('docker run', :args => parameters)
      container_id = result.output.strip

      container_id
    end

    def self.run(image, command = nil, options = {})
      raise_on_failure = options[:raise_on_failure].nil? || options[:raise_on_failure]

      container_id = start_daemon image, command, options

      Citac::Utils::Exec.run "docker logs -f #{container_id}", :stdout => :passthrough if options[:output] == :passthrough

      exit_code = Citac::Utils::Exec.run("docker wait #{container_id}").output.strip.to_i
      output = Citac::Utils::Exec.run("docker logs #{container_id}").output

      raise "Running '#{command}' on '#{image}' failed with exit code #{exit_code}: #{output}" unless exit_code == 0 || !raise_on_failure
      DockerRunResult.new output, exit_code, container_id
    ensure
      keep_container = options[:keep_container] && exit_code == 0
      Citac::Utils::Exec.run "docker rm #{container_id}", :raise_on_failure => false if container_id && !keep_container
    end

    def self.commit(container_id, repository_name, tag = nil)
      tag_suffix = tag ? ":#{tag}" : ''
      Citac::Utils::Exec.run "docker commit #{container_id} #{repository_name}#{tag_suffix}"
    end

    def self.containers
      ids = []

      result = Citac::Utils::Exec.run 'docker ps --all --quiet --no-trunc'
      result.output.each_line do |line|
        id = line.strip
        ids << id unless id.length == 0
      end

      ids
    end

    def self.cleanup_containers
      Citac::Utils::Exec.run 'docker ps --all --quiet --filter status=exited --no-trunc | xargs docker rm'
    end

    private

    def self.mounts_to_parameters(mounts)
      result = []

      mounts = mounts || []
      mounts.each do |(s,t,w)|
        type = w ? 'rw' : 'ro'

        result << '-v'
        result << "#{s}:#{t}:#{type}"
      end

      result
    end
  end
end