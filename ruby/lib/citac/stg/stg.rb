require_relative '../utils/graph'

module Citac
  def self.generate_stg(specification)
    stg = Utils::Graphs::Graph.new
    stg.add_node []

    loop do
      changed = false

      pending_nodes = stg.nodes.select{|n| n.outgoing_nodes.empty?}.reject{|n| n.label == specification.resources}
      pending_nodes.each do |pending_node|
        pending_resources = specification.resources - pending_node.label
        possible_resources = pending_resources.select {|p| (specification.deps(p) - pending_node.label).empty?}.to_a

        possible_resources.each do |resource|
          new_label = pending_node.label + [resource]
          new_label.sort!

          stg.add_node new_label unless stg.include? new_label
          new_node = stg.node new_label

          stg.add_edge pending_node, new_node, label = resource
          changed = true
        end
      end

      break unless changed
    end

    stg
  end
end