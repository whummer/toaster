require_relative '../utils/graph'

module Citac
  class ConfigurationSpecification
    def to_stg
      stg = Utils::Graphs::Graph.new
      start_node = stg.add_node []

      resource_deps = Hash.new { |h, k| h[k] = deps(k) }
      sorted_resources = resources.sort.to_a

      pending_nodes = [start_node]
      while pending_node = pending_nodes.shift
        satisfied_resources = pending_node.label
        pending_resources = sorted_resources - satisfied_resources
        possible_resources = pending_resources.select { |p| (resource_deps[p] - satisfied_resources).empty? }.to_a

        possible_resources.each do |resource|
          new_label = satisfied_resources + [resource]
          new_label.sort!

          new_node = stg.node new_label
          unless new_node
            new_node = stg.add_node new_label
            pending_nodes << new_node
          end

          stg.add_edge pending_node, new_node, resource
        end
      end

      stg
    end
  end
end