require_relative '../utils/graph'

module Citac
  class ConfigurationSpecification
    attr_reader :resource_count

    def initialize(resource_count)
      @resource_count = resource_count
      @graph = Utils::Graphs::Graph.new

      1.upto resource_count do |i|
        @graph.add_node i
      end
    end

    def resources
      (1..@resource_count).to_a
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