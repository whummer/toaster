require_relative '../base'
require_relative 'dot'
require_relative '../../exec'

module Citac
  module Utils
    module Graphs
      class Graph
        def to_png(options = {})
          dot = to_dot options
          dot = dot.encode 'ASCII-8BIT'

          IO.popen 'dot -Tpng', 'r+b:ASCII-8BIT' do |f|
            f.puts dot
            f.close_write

            f.read
          end
        end
      end
    end
  end
end