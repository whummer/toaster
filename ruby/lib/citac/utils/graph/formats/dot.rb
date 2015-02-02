require_relative '../base'

module Citac
  module Utils
    module Graphs
      class Graph
        def to_dot(options = {})
          node_label_getter = options[:node_label_getter] || lambda {|n| n.label}
          edge_label_getter = options[:edge_label_getter] || lambda {|e| e.label}
          direction = options[:direction] || 'TB'

          result = []
          result << 'digraph g {'
          result << "    rankdir = #{direction};"
          result << ''

          ns = nodes.to_a
          node_indices = Hash.new

          ns.each_index do |i|
            node_indices[ns[i]] = i

            label = node_label_getter.call(ns[i]).to_s.gsub '"', '\\"'
            result << "    n#{i} [label = \"#{label}\"];"
          end

          result << ''

          ns.each_index do |source_index|
            source_node = ns[source_index]
            source_node.outgoing_edges.each do |edge|
              target_index = node_indices[edge.target]

              label = edge_label_getter.call edge
              if label && label.to_s.strip.length > 0
                label = label.to_s.gsub '"', '\\"'
                result << "    n#{source_index} -> n#{target_index} [label = \"#{label}\"];"
              else
                result << "    n#{source_index} -> n#{target_index};"
              end
            end
          end

          result << '}'

          result.join "\n"
        end
      end
    end
  end
end