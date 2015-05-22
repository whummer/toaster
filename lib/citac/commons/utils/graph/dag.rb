require 'set'

module Citac
  module Utils
    module Graphs
      module DAG
        class << self
          def edge_cover_paths(graph)
            sorted = graph.toposort
            raise 'Graph is not a DAG.' unless sorted

            edge_counters = Hash.new
            sorted.each do |node|
              count = node.incoming_edges.collect{|e| edge_counters[e]}.reduce(1, :+)
              node.outgoing_edges.each do |edge|
                edge_counters[edge] = count
              end
            end

            paths = []
            visited_edges = Set.new
            sorted.reverse_each do |node|
              non_visited_edges = node.incoming_edges.reject{|e| visited_edges.include? e}
              next if non_visited_edges.empty?

              non_visited_edges.each do |non_visited_edge|
                edge_path = edge_cover_build_path non_visited_edge.source, edge_counters
                edge_path << non_visited_edge
                edge_path.each_with_index do |edge, index|
                  edge_counters[edge] -= index + 1
                  visited_edges << edge
                end

                node_path = edge_path.collect{|e| e.source}
                node_path << node

                paths << node_path
              end
            end

            paths
          end

          private

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