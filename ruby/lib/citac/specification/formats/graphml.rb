require_relative '../core'
require_relative '../../utils/graph'

module Citac
  class ConfigurationSpecification
    def self.from_graphml(io)
      graph = Citac::Utils::Graphs::Graph.from_graphml io
      ConfigurationSpecification.new graph
    end
  end
end