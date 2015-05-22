require 'set'
require_relative '../../commons/utils/graph'
require_relative 'dependency_graph'

module Citac
  module Core
    class StgBuilder
      attr_reader :stg

      def initialize(dependency_graph)
        @dependency_graph = dependency_graph
        @stg = Citac::Utils::Graphs::Graph.new
        @stg.add_node []
      end

      def add_state(executed_resources)
        executed_resources = expand_resources executed_resources

        end_node = @stg.node executed_resources
        unless end_node
          possible_start_nodes = @stg.nodes.select do |node|
            missing_resources = executed_resources - node.label
            node.label.size + missing_resources.size == executed_resources.size
          end

          start_node = possible_start_nodes.sort_by { |n| (executed_resources - n.label).size }.first

          end_node = @stg.add_node executed_resources
          connect_nodes start_node, end_node
        end

        end_node
      end

      def add_transition(from_resources, to_resources)
        from_resources = expand_resources from_resources
        to_resources = expand_resources to_resources

        raise "'#{from_resources.join(', ')}' (from) is not a subset of '#{to_resources.join(', ')}' (to)." unless (from_resources - to_resources).empty?

        missing_resources = to_resources - from_resources
        return if missing_resources.empty?

        raise "Expected one missing resource, but got #{missing_resources.size}: #{missing_resources.join(', ')}" unless missing_resources.size == 1

        start_node = add_state from_resources
        end_node = add_state to_resources

        @stg.add_edge start_node, end_node, missing_resources.first
      end

      def add_missing_edges
        @stg.nodes.each do |node|
          satisfied_resources = node.label
          possible_resources = @dependency_graph.possible_resources(satisfied_resources)

          possible_resources.each do |possible_resource|
            other = @stg.node (satisfied_resources + [possible_resource]).sort
            @stg.add_edge node, other, possible_resource if other
          end
        end
      end

      def expand(steps)
        steps.times do
          existing_nodes = @stg.nodes.dup
          existing_nodes.each do |existing_node|
            satisfied_resources = existing_node.label
            possible_resources = @dependency_graph.possible_resources(satisfied_resources)

            possible_resources.each do |possible_resource|
              add_transition satisfied_resources, (satisfied_resources + [possible_resource]).sort
            end
          end
        end
      end

      private

      def expand_resources(executed_resources)
        expanded = executed_resources.to_set

        executed_resources.each do |executed_resource|
          @dependency_graph.ancestors(executed_resource).each do |ancestor|
            expanded << ancestor
          end
        end

        expanded.to_a.sort
      end

      def connect_nodes(start_node, end_node)
        raise "Cannot connect '#{start_node.label.join(', ')}' to '#{end_node.label.join(', ')}'." if start_node.label.size >= end_node.label.size

        pending_resources = end_node.label - start_node.label
        resource_to_add = pending_resources.select { |r| dependencies_met? start_node, r }.first

        new_resources = start_node.label + [resource_to_add]
        new_resources.sort!

        new_node = @stg.node(new_resources) || @stg.add_node(new_resources)
        @stg.add_edge start_node, new_node, resource_to_add

        unless (end_node.label - new_node.label).empty?
          connect_nodes new_node, end_node
        end
      end

      def dependencies_met?(node, resource)
        missing_deps = @dependency_graph.deps(resource) - node.label
        missing_deps.empty?
      end
    end
  end
end