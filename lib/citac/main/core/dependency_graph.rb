require_relative '../../commons/utils/graph'
require_relative '../../commons/model/test'

module Citac
  module Core
    class DependencyGraph
      attr_reader :graph

      def initialize(graph)
        raise 'Graph is cyclic' if graph.cyclic?

        @graph = graph
        update_sorted

        expand
      end

      def resources
        @sorted.map(&:label).to_a
      end

      def resource_count
        @graph.nodes.size
      end

      def deps(resource)
        @graph[resource].incoming_nodes.map(&:label)
      end

      def ancestors(resource)
        if @expanded
          nodes = @graph[resource].incoming_nodes.dup
        else
          nodes = @graph.calculate_reaching_nodes(resource).to_a
          nodes.delete @graph[resource]
        end

        nodes.sort_by! {|r| @sorted_rtoi[r]}
        nodes.map(&:label).to_a
      end

      def successors(resource)
        if @expanded
          nodes = @graph[resource].outgoing_nodes.dup
        else
          nodes = @graph.calculate_reachable_nodes(resource).to_a
          nodes.delete @graph[resource]
        end

        nodes.sort_by! {|r| @sorted_rtoi[r]}
        nodes.map(&:label).to_a
      end

      def non_related_resources(resource)
        result = resources
        result.delete resource
        result -= ancestors(resource)
        result -= successors(resource)
        result
      end

      def possible_resources(satisfied_resources)
        pending_resources = resources - satisfied_resources
        pending_resources.select{|p| ancestors(p).all? {|a| satisfied_resources.include? a}}
      end

      def add_dep(prerequisite, resource)
        raise "prerequisite '#{prerequisite}' is unknown" unless @graph.include? prerequisite
        raise "resource '#{resource}' is unknown" unless @graph.include? resource
        raise "Failed to add #{prerequisite} as prerequisite for #{resource} due to a dependency cycle." if ancestors(prerequisite).include? resource

        @graph.add_edge prerequisite, resource
      end

      def reduce
        resources.reverse_each do |resource|
          current_successors = successors resource
          ancestors(resource).each do |ancestor|
            current_successors.each do |successor|
              @graph.delete_edge ancestor, successor
            end
          end
        end

        update_sorted
        @expanded = false
      end

      def expand
        return if @expanded

        resources.each do |resource|
          successors(resource).each do |successor|
            @graph.add_edge resource, successor
          end
        end

        update_sorted
        @expanded = true
      end

      def ordering_factor
        expand

        actual_edge_count = @graph.edges.size
        possible_edge_count = resource_count * (resource_count - 1) / 2

        actual_edge_count.to_f / possible_edge_count.to_f
      end

      def required_properties
        result = []
        resources.each do |resource|
          result << Citac::Model::Property.new(:idempotence, [resource])
          ancestors(resource).each do |ancestor|
            result << Citac::Model::Property.new(:preservation, [resource, ancestor])
          end
          non_related_resources(resource).each do |non_related|
            result << Citac::Model::Property.new(:preservation, [resource, non_related])
          end
        end

        result
      end

      private

      def update_sorted
        @sorted = @graph.toposort
        @sorted_rtoi = Hash.new
        @sorted.each_with_index { |r, i| @sorted_rtoi[r] = i }
      end
    end
  end
end