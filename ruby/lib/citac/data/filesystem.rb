require 'fileutils'
require_relative 'model'
require_relative '../providers'
require_relative '../utils/file'
require_relative '../utils/graph'

module Citac
  module Data
    class FileSystemSpecificationRepository
      def initialize(root)
        @root = File.expand_path root
      end

      def each_spec
        range = 0..@root.length
        Citac::Utils::DirectoryTraversal.each_dir @root do |dir|
          if dir.end_with? '.spec'
            dir.slice! range
            dir.slice! -5, 5

            yield dir

            Citac::Utils::DirectoryTraversal.prune
          end
        end
      end

      def specs
        result = []
        each_spec {|s| result << s}
        result
      end

      def get(spec_id)
        dir = spec_dir spec_id
        metadata_path = File.join dir, 'metadata.json'
        metadata_json = IO.read metadata_path, :encoding => 'UTF-8'

        metadata = JSON.parse metadata_json
        type = metadata['type']

        oss = metadata['operating-systems'] || []
        oss.map! {|os| OperatingSystem.parse os}

        ConfigurationSpecification.new spec_id, spec_id, type, metadata[type], oss
      end

      def has_dependency_graph?(spec, os_name, os_version)
        dir = graph_dir spec, os_name, os_version
        path = File.join dir, 'dependencies.graphml'
        File.exist? path
      end

      def dependency_graph(spec, os_name, os_version)
        dir = graph_dir spec, os_name, os_version
        path = File.join dir, 'dependencies.graphml'
        return nil unless File.exist? path

        graphml = IO.read path, :encoding => 'UTF-8'
        Citac::Utils::Graphs::Graph.from_graphml graphml
      end

      def save_dependency_graph(spec, os_name, os_version, graph)
        dir = graph_dir spec, os_name, os_version
        FileUtils.makedirs dir

        IO.write File.join(dir, 'dependencies.graphml'), graph.to_graphml, :encoding => 'UTF-8'
        IO.write File.join(dir, 'dependencies.dot'), graph.to_dot(:tred => true), :encoding => 'UTF-8'
      end

      def script(spec, os_name, os_version)
        path = script_path spec, os_name, os_version
        IO.read path, :encoding => 'UTF-8'
      end

      private

      def spec_dir(spec)
        id = spec.respond_to?(:id) ? spec.id : spec.to_s
        File.join @root, "#{id}.spec"
      end

      def graph_dir(spec, os_name, os_version)
        File.join spec_dir(spec), 'graphs', "#{os_name}-#{os_version}"
      end

      def script_path(spec, os_name, os_version)
        provider = Providers.get spec.type
        ext = provider.script_extension

        dir = spec_dir spec
        script_dir = File.join dir, 'scripts'

        file_path = File.join script_dir, "#{os_name}-#{os_version}#{ext}"
        return file_path if File.exist? file_path

        file_path = File.join script_dir, "#{os_name}#{ext}"
        return file_path if File.exist? file_path

        file_path = File.join script_dir, "default#{ext}"
        return file_path if File.exist? file_path

        raise "Unable to locate script file for spec '#{spec}' for os '#{os_name}-#{os_version}'."
      end
    end
  end
end