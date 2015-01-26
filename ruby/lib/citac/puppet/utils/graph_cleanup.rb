require_relative '../../utils/graph'

module Citac
  module Puppet
    module Utils
      module GraphCleanup
        class << self
          def cleanup_expanded_relationships(graph)
            remove_node_type graph, ['Schedule', 'Filebucket[puppet]', 'Whit']
          end

          private

          def remove_node_type(graph, type, delete_edges = true)
            graph.nodes.select{|n| is_node_type? n, type}.to_a.each do |node|
              if delete_edges
                delete_node_keep_edges graph, node
              else
                unless node.has_incoming_edges? || node.has_outgoing_edges?
                  graph.delete_node node
                end
              end
            end
          end

          def is_node_type?(node, type)
            if type.respond_to? :any?
              type.any? {|t| is_node_type? node, t}
            else
              if type.include? '['
                node.label.start_with? type
              else
                node.label.start_with? "#{type}["
              end
            end
          end

          def delete_node_keep_edges(graph, node)
            outs = node.outgoing_edges.to_a
            ins = node.incoming_edges.to_a

            ins.each do |in_edge|
              outs.each do |out_edge|
                graph.add_edge in_edge.source, out_edge.target
              end
            end

            graph.delete_node node, true
          end
        end
      end
    end
  end
end