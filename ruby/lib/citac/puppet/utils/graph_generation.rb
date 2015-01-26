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

            if system "citac-puppet apply --noop --graph \"#{manifest_path}\""
              path = Pathname.new manifest_path

              Dir.glob "#{graphdir}/*" do |source_file|
                suffix = ".#{File.basename source_file}"
                target_file = path.sub_ext(suffix).to_path
                FileUtils.copy source_file, target_file

                if File.basename(source_file) == 'expanded_relationships.graphml'
                  graph = Citac::Utils::Graphs::Graph.from_graphml IO.read(source_file)
                  GraphCleanup.cleanup_expanded_relationships graph

                  target_file = path.sub_ext('.expanded_relationships.clean.graphml').to_path
                  IO.write target_file, graph.to_graphml

                  target_file = path.sub_ext('.expanded_relationships.clean.dot').to_path
                  IO.write target_file, graph.to_dot
                end
              end
            end
          end

          private

          def graphdir
            @graphdir = `citac-puppet config print graphdir`.strip unless @graphdir
            @graphdir
          end
        end
      end
    end
  end
end