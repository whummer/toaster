require_relative '../../../helper'
require_relative '../../../../lib/citac/utils/graph'
require_relative '../../../../lib/citac/puppet/utils/graph_cleanup'

describe Citac::Puppet::Utils::GraphCleanup do
  before :each do
    @graph = Citac::Utils::Graphs::Graph.from_graphml graphml
    Citac::Puppet::Utils::GraphCleanup.cleanup_expanded_relationships @graph
  end

  it 'should reduce keep only real resources' do
    expect(@graph.nodes.size).to eq(3)
  end

  let(:graphml) do
    '<?xml version="1.0" encoding="utf-8"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://graphml.graphdrawing.org/xmlns http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd">
  <key id="d_label" for="all" attr.name="label" attr.type="string"/>
  <graph id="G" edgedefault="directed">
    <node id="n0">
      <data key="d_label">Package[ntp]</data>
    </node>
    <node id="n1">
      <data key="d_label">Service[ntp]</data>
    </node>
    <node id="n2">
      <data key="d_label">File[/etc/ntp.conf]</data>
    </node>
    <node id="n3">
      <data key="d_label">Schedule[puppet]</data>
    </node>
    <node id="n4">
      <data key="d_label">Schedule[hourly]</data>
    </node>
    <node id="n5">
      <data key="d_label">Schedule[daily]</data>
    </node>
    <node id="n6">
      <data key="d_label">Schedule[weekly]</data>
    </node>
    <node id="n7">
      <data key="d_label">Schedule[monthly]</data>
    </node>
    <node id="n8">
      <data key="d_label">Schedule[never]</data>
    </node>
    <node id="n9">
      <data key="d_label">Filebucket[puppet]</data>
    </node>
    <node id="n10">
      <data key="d_label">Whit[Admissible_stage[main]]</data>
    </node>
    <node id="n11">
      <data key="d_label">Whit[Completed_stage[main]]</data>
    </node>
    <node id="n12">
      <data key="d_label">Whit[Admissible_class[Settings]]</data>
    </node>
    <node id="n13">
      <data key="d_label">Whit[Completed_class[Settings]]</data>
    </node>
    <node id="n14">
      <data key="d_label">Whit[Admissible_class[Main]]</data>
    </node>
    <node id="n15">
      <data key="d_label">Whit[Completed_class[Main]]</data>
    </node>
    <node id="n16">
      <data key="d_label">Whit[Admissible_node[default]]</data>
    </node>
    <node id="n17">
      <data key="d_label">Whit[Completed_node[default]]</data>
    </node>
    <node id="n18">
      <data key="d_label">Whit[Admissible_class[Ntp]]</data>
    </node>
    <node id="n19">
      <data key="d_label">Whit[Completed_class[Ntp]]</data>
    </node>
    <edge id="e0" source="n18" target="n0"/>
    <edge id="e1" source="n0" target="n1"/>
    <edge id="e2" source="n2" target="n1"/>
    <edge id="e3" source="n18" target="n1"/>
    <edge id="e4" source="n18" target="n2"/>
    <edge id="e5" source="n13" target="n11"/>
    <edge id="e6" source="n15" target="n11"/>
    <edge id="e7" source="n19" target="n11"/>
    <edge id="e8" source="n10" target="n12"/>
    <edge id="e9" source="n12" target="n13"/>
    <edge id="e10" source="n10" target="n14"/>
    <edge id="e11" source="n17" target="n15"/>
    <edge id="e12" source="n14" target="n16"/>
    <edge id="e13" source="n16" target="n17"/>
    <edge id="e14" source="n10" target="n18"/>
    <edge id="e15" source="n0" target="n19"/>
    <edge id="e16" source="n1" target="n19"/>
    <edge id="e17" source="n2" target="n19"/>
  </graph>
</graphml>'
  end
end