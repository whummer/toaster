require_relative '../base'
require_relative '../../../logging'

module Citac
  module Utils
    module Graphs
      class Graph
        def to_dot(options = {})
          node_label_getter = options[:node_label_getter] || lambda {|n| n.label}
          edge_label_getter = options[:edge_label_getter] || lambda {|e| e.label}
          edge_attribute_getter = options[:edge_attribute_getter] || lambda {|_| Hash.new}
          direction = options[:direction] || 'TB'

          result = []
          result << 'digraph g {'
          result << "    rankdir = #{direction};"
          result << ''

          ns = nodes.to_a
          node_indices = Hash.new

          ns.each_index do |i|
            node_indices[ns[i]] = i

            label = node_label_getter.call(ns[i]).to_s
            label = label.gsub('\\', '\\\\\\').gsub('"', '\"')
            result << "    n#{i} [label = \"#{label}\"];"
          end

          result << ''

          ns.each_index do |source_index|
            source_node = ns[source_index]
            source_node.outgoing_edges.each do |edge|
              target_index = node_indices[edge.target]

              label = edge_label_getter.call edge
              label = label.to_s.gsub('\\', '\\\\\\').gsub('"', '\"') if label && label.to_s.strip.length > 0

              attributes = edge_attribute_getter.call(edge) || {}
              attributes_suffix = ''
              attributes.each do |name, value|
                next if name.to_s == 'penwidth' && value == 1

                attributes_suffix << ", #{name} = #{value}"
              end

              result << "    n#{source_index} -> n#{target_index} [label = \"#{label}\"#{attributes_suffix}];"
            end
          end

          result << '}'

          dot = result.join "\n"
          dot = apply_tred dot if options[:tred]
          dot
        end

        private

        def apply_tred(dot)
          begin
            log_debug 'graph', 'Applying transitive reduction to graph...'
            IO.popen 'tred', 'r+' do |f|
              f.puts dot
              f.close_write

              f.read
            end
          rescue StandardError => e
            log_warn 'graph', 'Failed to apply transitive reduction to graph', e
            dot
          end
        end
      end
    end
  end
end