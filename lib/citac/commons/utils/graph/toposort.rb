require_relative 'base'

module Citac
  module Utils
    module Graphs
      class Graph
        def toposort
          total_order = []
          ordered = Hash.new
          pending = nodes.to_a

          while pending.size > 0
            nodes = pending.select{|p| p.incoming_nodes.all? {|i| ordered[i]}}.to_a
            if nodes.empty?
              return nil
            else
              nodes.each do |n|
                total_order << n
                ordered[n] = true
                pending.delete n
              end
            end
          end

          total_order
        end

        def cyclic?
          toposort.nil?
        end
      end
    end
  end
end