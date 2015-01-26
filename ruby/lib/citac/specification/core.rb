require_relative '../utils/graph'

require_relative 'formats/confspec'
require_relative 'formats/graphml'
require_relative 'stg'

module Citac
  class ConfigurationSpecification
    def initialize(graph)
      raise 'Graph is cyclic' if graph.cyclic?
      @graph = graph
    end

    def resources
      @graph.nodes.map(&:label).sort.to_a
    end

    def resource_count
      @graph.nodes.size
    end

    def deps(resource)
      @graph[resource].incoming_nodes.map(&:label)
    end

    def alldeps(resource)
      nodes = @graph.calculate_reaching_nodes resource
      nodes.delete @graph[resource]
      nodes.map(&:label).to_a
    end

    def add_dep(prerequisite, resource)
      raise "prerequisite '#{prerequisite}' is unknown" unless @graph.include? prerequisite
      raise "resource '#{resource}' is unknown" unless @graph.include? resource
      raise "Failed to add #{prerequisite} as prerequisite for #{resource} due to a dependency cycle." if alldeps(prerequisite).include? resource

      @graph.add_edge prerequisite, resource
    end
  end
end