require_relative '../../commons/utils/graph'

module Citac
  module Core
    class DependencyGraph
      def initialize(graph)
        raise 'Graph is cyclic' if graph.cyclic?

        @graph = graph
        @sorted = graph.toposort
      end

      def resources
        @graph.nodes.map(&:label).sort.to_a
      end

      def resource_count
        @graph.nodes.size
      end

      def deps(resource)
        @graph[resource].incoming_nodes.map(&:label)
      end

      def ancestors(resource)
        nodes = @graph.calculate_reaching_nodes(resource).to_a
        nodes.delete @graph[resource]
        nodes.sort_by! {|r| @sorted.index(r)}
        nodes.map(&:label).to_a
      end

      def successors(resource)
        nodes = @graph.calculate_reachable_nodes(resource).to_a
        nodes.delete @graph[resource]
        nodes.sort_by! {|r| @sorted.index(r)}
        nodes.map(&:label).to_a
      end

      def non_related_resources(resource)
        result = resources
        result.delete resource
        result -= ancestors(resource)
        result -= successors(resource)
        result
      end

      def add_dep(prerequisite, resource)
        raise "prerequisite '#{prerequisite}' is unknown" unless @graph.include? prerequisite
        raise "resource '#{resource}' is unknown" unless @graph.include? resource
        raise "Failed to add #{prerequisite} as prerequisite for #{resource} due to a dependency cycle." if ancestors(prerequisite).include? resource

        @graph.add_edge prerequisite, resource
      end
    end
  end
end