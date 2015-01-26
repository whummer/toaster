require 'rexml/document'

doc = REXML::Document.new #'<?xml version="1.0" encoding="utf-8"?>'
doc.context[:attribute_quote] = :quote
doc.add REXML::XMLDecl.new

root = doc.add_element 'graphml'
root.add_namespace 'http://graphml.graphdrawing.org/xmlns'
root.add_namespace 'xsi', 'http://www.w3.org/2001/XMLSchema-instance'
root.add_attribute 'xsi:schemaLocation', 'http://graphml.graphdrawing.org/xmlns http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd'

graph = root.add_element 'graph'
graph.add_attribute 'id', 'G'
graph.add_attribute 'edgedefault', 'directed'

node1 = graph.add_element 'node'
node1.add_attribute 'id', 'n1'

node2 = graph.add_element 'node'
node2.add_attribute 'id', 'n2'

edge = graph.add_element 'edge'
edge.add_attribute 'id', 'e1'
edge.add_attribute 'source', 'n1'
edge.add_attribute 'target', 'n2'

output = ''

formatter = REXML::Formatters::Pretty.new
formatter.write doc, output

doc = REXML::Document.new output

nsm = {'' => 'http://graphml.graphdrawing.org/xmlns'}
x = REXML::XPath.first doc, "/graphml/graph/edge[@id = 'e1' and @source = 'n1']", nsm
puts x.inspect

