require 'fileutils'
require 'pathname'

require_relative '../../utils/exec'
require_relative '../../utils/graph'
require_relative 'graph_cleanup'

module Citac
  module Puppet
    module Utils
      module GraphGeneration
        class << self
          def generate_graphs(manifest_path, options = {})
            target_dir = options[:target_dir] || File.dirname(manifest_path)
            generate_dot = options[:generate_dot]

            FileUtils.rm_rf graphdir if Dir.exist? graphdir
            FileUtils.makedirs graphdir

            args = ['--noop', '--graph']
            args += ['--modulepath', options[:modulepath]] if options[:modulepath]
            args << manifest_path

            Citac::Utils::Exec.run 'citac-puppet apply', :args => args

            manifest_name = File.basename manifest_path, '.*' # file name without extension

            Dir.glob "#{graphdir}/*.graphml" do |source_path|
              graph_name = File.basename source_path, '.graphml'

              target_path_graphml = File.join target_dir, "#{manifest_name}.#{graph_name}.graphml"
              target_path_dot = File.join target_dir, "#{manifest_name}.#{graph_name}.dot"

              cleanup_method_name = "cleanup_#{graph_name}"
              cleanup_available = GraphCleanup.respond_to? cleanup_method_name

              if cleanup_available || generate_dot
                graphml = IO.read source_path, :encoding => 'UTF-8'
                graph = Citac::Utils::Graphs::Graph.from_graphml graphml

                GraphCleanup.send cleanup_method_name, graph if cleanup_available
                IO.write target_path_graphml, graph.to_graphml, :encoding => 'UTF-8'
                IO.write target_path_dot, graph.to_dot, :encoding => 'UTF-8' if generate_dot
              else
                FileUtils.copy source_path, target_path_graphml
              end
            end
          end

          private

          def graphdir
            unless @graphdir
              result = Citac::Utils::Exec.run 'citac-puppet config print graphdir', :stderr => :discard
              @graphdir = result.output.strip
            end

            @graphdir
          end

          # def cleanup_graph(graph_name, target_path)
          #   graph_type = File.basename source_file, '.*'
          #
          #   graph = Citac::Utils::Graphs::Graph.from_graphml IO.read(source_file)
          #
          #   cleanup_method_name = "cleanup_#{graph_name}"
          #   if GraphCleanup.respond_to? cleanup_method_name
          #     GraphCleanup.send cleanup_method_name, graph
          #
          #     graphml_path = target_path.sub_ext('.clean.graphml')
          #     dot_path = target_path.sub_ext('.clean.dot')
          #     dot_reduced_path = target_path.sub_ext('.clean.reduced.dot')
          #
          #     IO.write graphml_path, graph.to_graphml
          #     IO.write dot_path, graph.to_dot(:direction => 'TB')
          #
          #     dot_reduced = Citac::Utils::Exec.run("tred \"#{dot_path}\"").output
          #     IO.write dot_reduced_path, dot_reduced
          #   end
          # end
        end
      end
    end
  end
end