require_relative '../utils/exec'

module Citac
  module Docker
    def self.run(image, command, options = {})
      image_id = image.respond_to?(:id) ? image.id : image.to_s
      mounts = options[:mounts] || []

      parameters = ''
      mounts.each {|(s,t,w)| parameters << " -v \"#{s}:#{t}:#{w ? 'rw' : 'ro'}\""}

      container_id = Citac::Utils::Exec.run("docker run -d #{parameters} #{image_id} #{command}").strip
      exit_code = Citac::Utils::Exec.run("docker wait #{container_id}").strip.to_i
      output = Citac::Utils::Exec.run "docker logs #{container_id}"

      raise "Running '#{command}' on '#{image}' failed with exit code #{exit_code}: #{output}" unless exit_code == 0

      output
    ensure
      Citac::Utils::Exec.run "docker rm #{container_id}", :raise_on_failure => false if container_id
    end

    def self.containers
      ids = []

      output = Citac::Utils::Exec.run 'docker ps --all --quiet --no-trunc'
      output.each_line do |line|
        id = line.strip
        ids << id unless id.length == 0
      end

      ids
    end

    def self.cleanup_containers
      Citac::Utils::Exec.run 'docker ps --all --quiet --filter status=exited --no-trunc | xargs docker rm'
    end
  end
end