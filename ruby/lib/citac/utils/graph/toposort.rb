module Citac
  module Utils
    module Graphs
      class Graph
        def toposort
          ordered = []
          pending = nodes.to_a

          while pending.size > 0
            nodes = pending.select{|p| (p.incoming_nodes - ordered).empty?}.to_a
            if nodes.empty?
              return nil
            else
              nodes.each do |n|
                ordered << n
                pending.delete n
              end
            end
          end

          ordered
        end
      end
    end
  end
end