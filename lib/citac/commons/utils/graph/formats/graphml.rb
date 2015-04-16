require 'rexml/document'
require 'rexml/formatters/pretty'
require_relative '../base'

module Citac
  module Utils
    module Graphs
      class Graph
        def self.from_graphml(xml)
          nsm = {'' => 'http://graphml.graphdrawing.org/xmlns'}

          graph = Graph.new
          doc = REXML::Document.new xml

          key_label_all = REXML::XPath.first doc, "/graphml/key[@attr.name = 'label' and @for = 'all']", nsm
          key_label_node = REXML::XPath.first doc, "/graphml/key[@attr.name = 'label' and @for = 'node']", nsm
          key_label_edge = REXML::XPath.first doc, "/graphml/key[@attr.name = 'label' and @for = 'edge']", nsm

          key_label_all_id = key_label_all ? key_label_all.attributes['id'] : nil
          key_label_node_id = key_label_node ? key_label_node.attributes['id'] : nil
          key_label_edge_id = key_label_edge ? key_label_edge.attributes['id'] : nil

          lim = {'all' => key_label_all_id, 'node' => key_label_node_id, 'edge' => key_label_edge_id}

          nodes = Hash.new

          REXML::XPath.each doc, '/graphml/graph/node', nsm do |node|
            id = node.attributes['id']
            label = REXML::XPath.first node, 'data[@key = $all or @key = $node]', nsm, lim
            label = label ? label.text.to_s : id

            nodes[id] = graph.add_node label
          end

          REXML::XPath.each doc, '/graphml/graph/edge', nsm do |edge|
            source_id = edge.attributes['source']
            target_id = edge.attributes['target']

            label = REXML::XPath.first edge, 'data[@key = $all or @key = $edge]', nsm, lim
            label = label.text if label

            graph.add_edge nodes[source_id], nodes[target_id], label
          end

          graph
        end

        def to_graphml
          node_indices = Hash.new
          nodes.each { |n| node_indices[n] = node_indices.size }

          doc = REXML::Document.new
          doc.context[:attribute_quote] = :quote

          root = doc.add_element 'graphml'
          root.add_namespace 'http://graphml.graphdrawing.org/xmlns'
          root.add_namespace 'xsi', 'http://www.w3.org/2001/XMLSchema-instance'
          root.add_attribute 'xsi:schemaLocation', 'http://graphml.graphdrawing.org/xmlns http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd'

          label_attribute = root.add_element 'key'
          label_attribute.add_attribute 'id', 'd_label'
          label_attribute.add_attribute 'for', 'all'
          label_attribute.add_attribute 'attr.name', 'label'
          label_attribute.add_attribute 'attr.type', 'string'

          graph = root.add_element 'graph'
          graph.add_attribute 'id', 'G'
          graph.add_attribute 'edgedefault', 'directed'

          node_indices.each do |n, i|
            node = graph.add_element 'node'
            node.add_attribute 'id', "n#{i}"

            if n.label
              label = node.add_element 'data'
              label.add_attribute 'key', 'd_label'
              label.text = n.label
            end
          end

          edges.each_with_index do |e, i|
            source_index = node_indices[e.source]
            target_index = node_indices[e.target]

            edge = graph.add_element 'edge'
            edge.add_attribute 'id', "e#{i}"
            edge.add_attribute 'source', "n#{source_index}"
            edge.add_attribute 'target', "n#{target_index}"

            if e.label
              label = edge.add_element 'data'
              label.add_attribute 'key', 'd_label'
              label.text = e.label
            end
          end

          output = '<?xml version="1.0" encoding="utf-8"?>'
          output << "\n"
          output.encode! 'utf-8'

          formatter = REXML::Formatters::Pretty.new
          formatter.compact = true
          formatter.width = 1000000
          formatter.write doc, output

          output
        end
      end
    end
  end
end