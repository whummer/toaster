require_relative '../dependency_graph'
require_relative '../../utils/graph'

module Citac
  module Core
    class DependencyGraph
      def self.from_graphml(io)
        graph = Citac::Utils::Graphs::Graph.from_graphml io
        DependencyGraph.new graph
      end
    end
  end
end