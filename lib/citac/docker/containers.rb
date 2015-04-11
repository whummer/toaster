require 'tmpdir'
require_relative '../utils/colorize'
require_relative '../utils/exec'
require_relative 'images'

module Citac
  module Docker
    class DockerRunResult < Citac::Utils::Exec::RunResult
      attr_reader :container_id

      def initialize(output, exit_code, stdout, stderr, container_id)
        super output, exit_code, stdout, stderr
        @container_id = container_id
      end
    end

    def self.start_daemon(image, command = nil, options = {})
      image_id = image.respond_to?(:id) ? image.id : image.to_s

      parameters = ['-d']
      parameters << '-i' if options[:stdin]
      parameters += ['--net', options[:network].to_s] if options[:network]
      parameters += mounts_to_parameters options[:mounts] if options[:mounts]
      parameters += ['--name', options[:name]] if options[:name]
      parameters << image_id
      parameters += command.respond_to?(:to_a) ? command.to_a : [command] if command

      result = Citac::Utils::Exec.run('docker run', :args => parameters)
      container_id = result.output.strip

      container_id
    end

    def self.run(image, command = nil, options = {})
      Dir.mktmpdir do |dir|
        raise_on_failure = options[:raise_on_failure].nil? || options[:raise_on_failure]
        cidfile = File.join dir, 'cid'

        image_id = image.respond_to?(:id) ? image.id : image.to_s

        parameters = ['-i']
        parameters << '--rm' unless options[:keep_container]
        parameters += ['--cidfile', cidfile]
        parameters += mounts_to_parameters options[:mounts] if options[:mounts]
        parameters << image_id
        parameters += command.respond_to?(:to_a) ? command.to_a : [command] if command

        exec_options = options.clone
        exec_options[:raise_on_failure] = false
        exec_options[:args] = parameters

        result = Citac::Utils::Exec.run 'docker run', exec_options
        container_id = IO.read(cidfile).strip

        if (result.exit_code != 0 || result.output.include?('PTRACE_TRACEME')) && result.output.include?('strace')
          puts "strace failed. Run 'aa-complain /etc/apparmor.d/docker' and try again.".yellow
        end

        if result.exit_code != 0 && raise_on_failure
          Citac::Utils::Exec.run "docker rm #{container_id}", :raise_on_failure => false if options[:keep_container]
          raise "Running '#{command}' on '#{image}' failed with exit code #{result.exit_code}: #{result.output}"
        end

        DockerRunResult.new result.output, result.exit_code, result.stdout, result.stderr, container_id
      end
    end

    def self.stop(container_id)
      Citac::Utils::Exec.run 'docker stop', :args => [container_id]
    end

    def self.commit(container_id, repository_name, tag = nil)
      tag_suffix = tag ? ":#{tag}" : ''
      result = Citac::Utils::Exec.run "docker commit #{container_id} #{repository_name}#{tag_suffix}"
      id = result.output.strip

      DockerImage.new id, repository_name, tag
    end

    def self.container_running?(container_id)
      result = Citac::Utils::Exec.run 'docker ps'
      result.output.include? container_id
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

    def self.remove(container_id)
      Citac::Utils::Exec.run 'docker rm', :args => [container_id]
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