require_relative '../../utils/graph'

module Citac
  module Puppet
    module Utils
      module GraphCleanup
        class << self
          def is_pseudo_resource?(resource)
            is_node_type? resource, ['Schedule', 'Filebucket[puppet]', 'Anchor', 'Stage', 'Class', 'Whit']
          end

          def is_real_resource?(resource)
            !is_pseudo_resource?(resource)
          end

          def cleanup_resources(graph)
            selector = lambda {|n| is_node_type? n, ['Schedule', 'Filebucket[puppet]', 'Anchor']}
            remove_nodes graph, selector, false
          end

          def cleanup_expanded_relationships(graph)
            remove_nodes graph, method(:is_pseudo_resource?), true
          end

          private

          def remove_nodes(graph, node_selector, delete_nodes_with_edges)
            graph.nodes.select{|n| node_selector.call n}.to_a.each do |node|
              if delete_nodes_with_edges
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
              name = node.respond_to?(:label) ? node.label : node.to_s

              if type.include? '['
                name.start_with? type
              else
                name.start_with? "#{type}["
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