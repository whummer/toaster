require_relative '../utils/exec'

module Citac
  module Docker
    class DockerImage
      attr_reader :id, :name, :tag

      def initialize(id, name, tag)
        @id = id
        @name = name
        @tag = tag
      end

      def full_name; "#{name}:#{tag}" end
      def to_s; full_name end
    end

    def self.images
      expr = /^(?'name'\S+)\s+(?'tag'\S+)\s+(?'id'[a-f0-9]{64})/i

      images = []

      output = Citac::Utils::Exec.run 'docker images --no-trunc'
      output.each_line do |line|
        match = expr.match line.strip
        images << DockerImage.new(match[:id], match[:name], match[:tag]) if match
      end

      images
    end
  end
end