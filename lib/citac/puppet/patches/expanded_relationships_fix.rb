require 'puppet/graph/simple_graph'

# Current versions of Puppet 3.x contain a bug which results in a wrong
# expanded relationships graph. This file fixes the bug by patching Puppet.
# See http://stackoverflow.com/a/28128418/128709 for details.

class Puppet::Graph::SimpleGraph
  def to_dot_graph (params = {})
    params['name'] ||= self.class.name.gsub(/:/,'_')
    fontsize   = params['fontsize'] ? params['fontsize'] : '8'
    graph      = (directed? ? DOT::DOTDigraph : DOT::DOTSubgraph).new(params)
    edge_klass = directed? ? DOT::DOTDirectedEdge : DOT::DOTEdge
    vertices.each do |v|
      name = v.ref
      params = {'name'     => '"'+name+'"',
                'fontsize' => fontsize,
                'label'    => name}
      v_label = v.ref
      params.merge!(v_label) if v_label and v_label.kind_of? Hash
      graph << DOT::DOTNode.new(params)
    end
    edges.each do |e|
      params = {'from'     => '"'+ e.source.ref + '"',
                'to'       => '"'+ e.target.ref + '"',
                'fontsize' => fontsize }
      e_label = e.ref
      params.merge!(e_label) if e_label and e_label.kind_of? Hash
      graph << edge_klass.new(params)
    end
    graph
  end
end