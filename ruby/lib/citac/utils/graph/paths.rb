require 'set'

module Citac
  module Utils
    module Graphs
      class Graph
        def each_path(source_node_or_label, destination_node_or_label)
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

        def path_count(source_node_or_label, destination_node_or_label)
          count = 0
          each_path source_node_or_label, destination_node_or_label do |_|
            count += 1
          end

          count
        end
      end
    end
  end
end