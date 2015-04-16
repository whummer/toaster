require 'fileutils'
require 'json'
require 'time'
require_relative '../../commons/model'
require_relative '../../commons/utils/file'
require_relative '../../commons/utils/graph'
require_relative '../../commons/utils/serialization'

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
        spec_id = clean_spec_id spec_id
        dir = spec_dir spec_id
        metadata_path = File.join dir, 'metadata.json'
        metadata_json = IO.read metadata_path, :encoding => 'UTF-8'

        metadata = JSON.parse metadata_json
        type = metadata['type']

        oss = metadata['operating-systems'] || []
        oss.map! {|os| Citac::Model::OperatingSystem.parse os}

        Citac::Model::ConfigurationSpecification.new spec_id, spec_id, type, metadata[type], oss
      end

      def has_dependency_graph?(spec, operating_system)
        dir = graph_dir spec, operating_system
        path = File.join dir, 'dependencies.graphml'
        File.exist? path
      end

      def dependency_graph(spec, operating_system)
        dir = graph_dir spec, operating_system
        path = File.join dir, 'dependencies.graphml'
        return nil unless File.exist? path

        graphml = IO.read path, :encoding => 'UTF-8'
        Citac::Utils::Graphs::Graph.from_graphml graphml
      end

      def save_dependency_graph(spec, operating_system, graph)
        dir = graph_dir spec, operating_system
        log_debug 'repo', "Saving dependency graph of '#{spec}' for '#{operating_system}' to '#{dir}'..."

        FileUtils.makedirs dir

        IO.write File.join(dir, 'dependencies.graphml'), graph.to_graphml, :encoding => 'UTF-8'
        IO.write File.join(dir, 'dependencies.dot'), graph.to_dot(:tred => true), :encoding => 'UTF-8'
      end

      def script(spec, operating_system)
        path = script_path spec, operating_system
        IO.read path, :encoding => 'UTF-8'
      end

      def get_additional_files(spec, target_dir)
        dir = additional_files_dir spec
        FileUtils.cp_r "#{dir}/.", target_dir if Dir.exist? dir
      end

      def run_count(spec)
        dir = runs_dir spec
        return 0 unless Dir.exist? dir

        Dir.entries(dir).reject { |e| e == '.' || e == '..' }.to_a.size
      end

      def runs(spec)
        dir = runs_dir spec
        return [] unless Dir.exist? dir

        result = []
        Dir.entries(dir).reject { |e| e == '.' || e == '..' }.sort_by{|d| d.to_i}.each do |d|
          metadata_json = IO.read File.join(dir, d, 'metadata.json'), :encoding => 'UTF-8'
          metadata = JSON.parse metadata_json
          result << Citac::Model::ConfigurationSpecificationRun.new(d.to_i, spec, metadata['action'],
              Citac::Model::OperatingSystem.parse(metadata['operating-system']), metadata['exit-code'],
              Time.parse(metadata['start-time']), Time.parse(metadata['end-time']), metadata['duration'])
        end

        result
      end

      def save_run(spec, operating_system, action, result, start_time, end_time)
        base_dir = runs_dir spec
        FileUtils.makedirs base_dir

        ids = Dir.entries(base_dir).reject { |e| e == '.' || e == '..' }.map { |e| e.to_i }.to_a
        ids << 0

        new_id = ids.max + 1
        dir = File.join base_dir, new_id.to_s.rjust(4, '0')
        FileUtils.makedirs dir

        metadata = {
            'action' => action,
            'operating-system' => operating_system.to_s,
            'start-time' => start_time,
            'end-time' => end_time,
            'duration' => end_time - start_time,
            'exit-code' => result.exit_code
        }

        metadata_json = JSON.pretty_generate metadata

        IO.write File.join(dir, 'metadata.json'), metadata_json, :encoding => 'UTF-8'
        IO.write File.join(dir, 'output.txt'), result.output, :encoding => 'UTF-8'

        Citac::Model::ConfigurationSpecificationRun.new(new_id, spec, action, operating_system, result.exit_code,
                                                        start_time, end_time, end_time - start_time)
      end

      def save_run_trace(spec, run, trace)
        id = run.respond_to?(:id) ? run.id : run.to_i
        dir = run_dir spec, id

        IO.write File.join(dir, 'trace.json'), trace, :encoding => 'UTF-8'
      end

      def delete_run(run)
        base_dir = runs_dir run.spec
        dir = File.join base_dir, run.id.to_s.rjust(4, '0')

        FileUtils.rm_rf dir if Dir.exist? dir
      end

      def save_test_case_result(spec, test_case_result)
        base_dir = test_case_result_dir spec
        dir = File.join base_dir, "testcase-#{test_case_result.test_case.id.to_s.rjust(4, '0')}"
        FileUtils.makedirs dir unless Dir.exists? dir

        ids = Dir.entries(dir).reject { |e| e == '.' || e == '..' }.map { |e| e.to_i }.to_a
        ids << 0

        new_id = ids.max + 1
        target_dir = File.join dir, new_id.to_s.rjust(4, '0')
        FileUtils.makedirs target_dir

        Citac::Utils::Serialization.write_to_file test_case_result, File.join(target_dir, 'test_case_result.yml')
        IO.write File.join(target_dir, 'test_case_result.txt'), test_case_result.to_s, :encoding => 'UTF-8'
      end

      private

      def clean_spec_id(id)
        id.gsub /\.spec\/?/i, ''
      end

      def spec_dir(spec)
        id = spec.respond_to?(:id) ? spec.id : spec.to_s

        File.join @root, "#{id}.spec"
      end

      def runs_dir(spec)
        File.join spec_dir(spec), 'runs'
      end

      def run_dir(spec, run_id)
        File.join runs_dir(spec), run_id.to_s.rjust(4, '0')
      end

      def graph_dir(spec, operating_system)
        raise "Operating system '#{operating_system}' is not fully specified" unless operating_system.specific?

        File.join spec_dir(spec), 'graphs', "#{operating_system}"
      end

      def additional_files_dir(spec)
        File.join spec_dir(spec), 'files'
      end

      def script_path(spec, operating_system)
        raise "Operating system '#{operating_system}' is not fully specified" unless operating_system.specific?

        dir = spec_dir spec
        script_dir = File.join dir, 'scripts'

        file_path = File.join script_dir, "#{operating_system}"
        return file_path if File.exist? file_path

        file_path = File.join script_dir, "#{operating_system.name}"
        return file_path if File.exist? file_path

        file_path = File.join script_dir, "default"
        return file_path if File.exist? file_path

        raise "Unable to locate script file for spec '#{spec}' for os '#{operating_system}'."
      end

      def test_case_result_dir(spec)
        File.join spec_dir(spec), 'tests-results'
      end
    end
  end
end