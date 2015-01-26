module Citac
  module Utils
    module Graphs
      class Graph
        def cyclic?
          toposort.nil?
        end
      end
    end
  end
end