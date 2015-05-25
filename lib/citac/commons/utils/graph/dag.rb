require 'set'

module Citac
  module Utils
    module Graphs
      module DAG
        class << self
          def edge_cover_paths(graph, options = {})
            sorted = graph.toposort
            raise 'Graph is not a DAG.' unless sorted

            edge_counters = Hash.new
            visited_edges = Set.new

            calculate_edge_counters sorted, edge_counters, visited_edges

            # dot_opts = {}
            # dot_opts[:node_label_getter] = options[:node_label_getter] || lambda{|n| n.label.join(', ')}
            # dot_opts[:edge_label_getter] = lambda{|e| edge_counters[e]}
            # dot_opts[:edge_attribute_getter] = lambda {|e| (visited_edges.include? e) ? {:penwidth => 3} : {}}
            #
            # i = 0
            # IO.write "/tmp/step#{i.to_s.rjust(2, '0')}.dot", graph.to_dot(dot_opts)

            paths = []
            sorted.reverse_each do |node|
              non_visited_edges = node.incoming_edges.reject{|e| visited_edges.include? e}.sort_by{|e| edge_counters[e]}
              next if non_visited_edges.empty?

              non_visited_edges.reverse_each do |non_visited_edge|
                edge_path = edge_cover_build_path non_visited_edge.source, edge_counters
                edge_path << non_visited_edge
                edge_path.each {|e| visited_edges << e}

                node_path = edge_path.collect{|e| e.source}
                node_path << node

                paths << node_path

                calculate_edge_counters sorted, edge_counters, visited_edges

                # i += 1
                # IO.write "/tmp/step#{i.to_s.rjust(2, '0')}.dot", graph.to_dot(dot_opts)
              end
            end

            paths
          end

          private

          def calculate_edge_counters(sorted, edge_counters, visited_edges)
            sorted.each do |node|
              count = node.incoming_edges.collect { |e| edge_counters[e] }.max || 0

              node.outgoing_edges.each do |edge|
                edge_counters[edge] = count
                edge_counters[edge] += 1 unless visited_edges.include? edge
              end
            end
          end

          def edge_cover_build_path(node, edge_counters)
            edge = node.incoming_edges.sort_by{|e| edge_counters[e]}.last
            return [] unless edge

            path = edge_cover_build_path edge.source, edge_counters
            path << edge

            path
          end
        end
      end
    end
  end
end