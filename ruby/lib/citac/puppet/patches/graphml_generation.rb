require 'puppet/graph/simple_graph'
require_relative '../../utils/graph'

# Extends Puppet to generate graphs in GraphML format in addition to DOT

class Puppet::Graph::SimpleGraph
  alias_method :__citac_original_write_graph, :write_graph

  def write_graph(name)
    return unless Puppet[:graph]

    __citac_original_write_graph name

    file = File.join Puppet[:graphdir], "#{name}.graphml"
    File.open(file, 'w') do |f|
      f.puts __citac_to_graphml
    end
  end

  def __citac_to_graphml
    unless directed?
      STDERR.puts 'Cannot generate GraphML graph from undirected graph.'
      return
    end

    graph = Citac::Utils::Graphs::Graph.new

    vertices.each do |v|
      graph.add_node v.ref
    end

    edges.each do |e|
      graph.add_edge e.source.ref, e.target.ref
    end

    graph.to_graphml
  end
end