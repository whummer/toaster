require 'fileutils'
require 'pathname'

require_relative '../../utils/graph'
require_relative 'graph_cleanup'

module Citac
  module Puppet
    module Utils
      module GraphGeneration
        class << self
          def generate_graphs(manifest_path)
            FileUtils.rm_rf graphdir if Dir.exists? graphdir
            FileUtils.makedirs graphdir

            output = `citac-puppet apply --noop --graph "#{manifest_path}" 2>&1`
            if $?.exitstatus == 0
              path = Pathname.new manifest_path

              Dir.glob "#{graphdir}/*" do |source_file|
                basename = File.basename(source_file)

                target_path = path.sub_ext ".#{basename}"
                FileUtils.copy source_file, target_path.to_path

                if File.extname(source_file) == '.graphml'
                  cleanup_graph source_file, target_path
                end
              end
            else
              raise "Failed to generate graphs. Exit code: #{$?.exitstatus}. Puppet output:\n#{output}"
            end
          end

          private

          def graphdir
            unless @graphdir
              output = `citac-puppet config print graphdir`
              if $?.exitstatus == 0 && output
                @graphdir = output.strip
              else
                message = output || "Exit code: #{$?.exitstatus}"
                raise "Failed to retrieve Puppet's graph dir: #{message}"
              end
            end

            @graphdir
          end

          def cleanup_graph(source_file, target_path)
            graph_type = File.basename source_file, '.*'

            graph = Citac::Utils::Graphs::Graph.from_graphml IO.read(source_file)

            cleanup_method_name = "cleanup_#{graph_type}"
            if GraphCleanup.respond_to? cleanup_method_name
              GraphCleanup.send cleanup_method_name, graph

              graphml_path = target_path.sub_ext('.clean.graphml')
              dot_path = target_path.sub_ext('.clean.dot')
              dot_reduced_path = target_path.sub_ext('.clean.reduced.dot')

              IO.write graphml_path, graph.to_graphml
              IO.write dot_path, graph.to_dot(:direction => 'TB')

              dot_reduced = `tred "#{dot_path}"`
              IO.write dot_reduced_path, dot_reduced
            end
          end
        end
      end
    end
  end
end