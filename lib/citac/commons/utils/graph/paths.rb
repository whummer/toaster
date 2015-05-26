require 'set'
require_relative 'base'
require_relative 'reachability'
require_relative 'toposort'

module Citac
  module Utils
    module Graphs
      class Graph
        def each_path(source_node_or_label, destination_node_or_label = nil)
          if destination_node_or_label
            each_path_dest source_node_or_label, destination_node_or_label do |path|
              yield path
            end
          else
            each_path_no_dest source_node_or_label do |path|
              yield path
            end
          end
        end

        def path_count(source_node_or_label, destination_node_or_label = nil)
          count = 0
          each_path source_node_or_label, destination_node_or_label do |_|
            count += 1
          end

          count
        end

        def dag_path_count
          sorted = toposort
          raise 'Cannot calculate path count for cyclic graph.' unless sorted

          numbered_nodes = Hash.new
          sorted.each do |node|
            if node.has_incoming_edges?
              numbered_nodes[node] = node.incoming_nodes.collect{|i| numbered_nodes[i]}.reduce(0, :+)
            else
              numbered_nodes[node] = 1
            end
          end

          destination_nodes = nodes.reject{|n| n.has_outgoing_edges?}
          destination_nodes.collect{|d| numbered_nodes[d]}.reduce(0, :+)
        end

        private

        def each_path_dest(source_node_or_label, destination_node_or_label)
          check_cycles = cyclic?

          source_node = get_node_safe source_node_or_label
          destination_node = get_node_safe destination_node_or_label

          path = [source_node]
          nxts = [source_node.outgoing_nodes]

          until path.empty?
            if path[-1] == destination_node
              yield path
              path.pop
              nxts.pop
            else
              next_node = nxts[-1].pop
              if next_node
                unless check_cycles && path.include?(next_node)
                  path.push next_node
                  nxts.push next_node.outgoing_nodes
                end
              else
                path.pop
                nxts.pop
              end
            end
          end
        end

        def each_path_no_dest(source_node_or_label)
          check_cycles = cyclic?

          source_node = get_node_safe source_node_or_label

          path = [source_node]
          nxts = [source_node.outgoing_nodes]

          until path.empty?
            next_node = nxts[-1].pop
            if next_node
              unless check_cycles && path.include?(next_node)
                path.push next_node

                outgoings = next_node.outgoing_nodes
                if outgoings.empty?
                  yield path
                  path.pop
                else
                  nxts.push outgoings
                end
              end
            else
              path.pop
              nxts.pop
            end
          end
        end
      end
    end
  end
end