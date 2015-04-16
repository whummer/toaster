require 'fileutils'
require 'pathname'
require 'tmpdir'

require_relative '../../utils/graph'
require_relative 'graph_cleanup'
require_relative 'runner'

module Citac
  module Integration
    module Puppet
      class << self
        def generate_graphs(manifest_path, options = {})
          Dir.mktmpdir do |graphdir|
            run_opts = options.dup
            run_opts[:noop] = true
            run_opts[:graph] = true
            run_opts[:graphdir] = graphdir
            run_opts[:raise_on_failure] = true

            result = Puppet.apply manifest_path, run_opts

            graph_types = options[:graph_types] || [:resources, :relationships, :expanded_relationships]

            graphs = Hash.new
            graph_types.each do |graph_type|
              graph = load_graph graphdir, graph_type
              graphs[graph_type] = graph
            end

            return graphs, result
          end
        end

        private

        def load_graph(graphdir, graph_type)
          path = File.join graphdir, "#{graph_type}.graphml"
          graphml = IO.read path, :encoding => 'UTF-8'

          graph = Citac::Utils::Graphs::Graph.from_graphml graphml

          cleanup_method_name = "cleanup_#{graph_type}"
          GraphCleanup.send cleanup_method_name, graph if GraphCleanup.respond_to? cleanup_method_name

          graph
        end
      end
    end
  end
end