require 'set'
require_relative 'base'

module Citac
  module Utils
    module Graphs
      class Graph
        def calculate_reaching_nodes(node_or_label)
          calculate_reachability node_or_label, &:incoming_nodes
        end

        def calculate_reachable_nodes(node_or_label)
          calculate_reachability node_or_label, &:outgoing_nodes
        end

        private

        def calculate_reachability(node_or_label)
          all = Set.new
          last = Set.new

          all << get_node_safe(node_or_label)
          last << get_node_safe(node_or_label)

          until last.empty?
            current = Set.new

            last.each do |node|
              edges = yield node
              edges.each do |incoming|
                unless all.include? incoming
                  current << incoming
                  all << incoming
                end
              end
            end

            last = current
          end

          all
        end
      end
    end
  end
end