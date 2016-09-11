require_relative '../dependency_graph'
require_relative '../../utils/graph'

module Citac
  module Core
    class DependencyGraph
      def self.from_confspec(io)
        graph = Citac::Utils::Graphs::Graph.new

        io.each do |line|
          if line.start_with? '#'
            next
          elsif graph.nodes.empty?
            resource_count = Integer(line)
            1.upto(resource_count) { |i| graph.add_node i }
          else
            resources = line.split(/\s/).map { |x| Integer(x) }
            to = resources.first
            resources.drop(1).each do |from|
              graph.add_edge from, to
            end
          end
        end

        DependencyGraph.new graph
      end
    end
  end
end