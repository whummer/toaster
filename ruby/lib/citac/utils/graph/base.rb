module Citac
  module Utils
    module Graphs
      class Graph
        def initialize
          @nodes = Hash.new
          @edges = []
        end

        def nodes; @nodes.values; end
        def edges; @edges; end

        def node(label); @nodes[label]; end
        def [](label); node label; end

        def include?(label); @nodes.include? label; end
        alias_method :exists?, :include?

        def add_node(label)
          raise "Node '#{label}' already exists." if @nodes.include? label

          node = GraphNode.new self, label
          @nodes[label] = node

          node
        end

        def delete_node(label_or_node, delete_edges = false)
          node = get_node_safe label_or_node, false
          if node
            if (!delete_edges) && (node.has_incoming_edges? || node.has_outgoing_edges?)
              raise "Cannot delete node '#{node}' because it has some edges."
            end

            if delete_edges
              node.incoming_edges.to_a.each {|e| delete_edge e}
              node.outgoing_edges.to_a.each {|e| delete_edge e}
            end

            @nodes.delete node.label
          end
        end

        def edge(source_label_or_node, target_label_or_node)
          source_node = get_node_safe source_label_or_node
          target_node = get_node_safe target_label_or_node

          source_node.outgoing_edge target_node
        end

        def add_edge(source_label_or_node, target_label_or_node, label = nil)
          source_node = get_node_safe source_label_or_node
          target_node = get_node_safe target_label_or_node

          existing_edge = source_node.outgoing_edge target_node
          return existing_edge if existing_edge

          edge = GraphEdge.new source_node, target_node, label
          source_node.add_outgoing_edge edge

          @edges << edge
          edge
        end

        def delete_edge(edge_or_source_label_or_node, target_label_or_node = nil)
          if target_label_or_node
            source_node = get_node_safe edge_or_source_label_or_node
            target_node = get_node_safe target_label_or_node
          else
            source_node = edge_or_source_label_or_node.source
            target_node = edge_or_source_label_or_node.target
          end

          edge = source_node.outgoing_edge target_node
          if edge
            source_node.delete_outgoing_edge edge
            @edges.delete edge
          end
        end

        private

        def get_node_safe(label_or_node, raise_error = true)
          raise 'Neither label nor node set.' unless label_or_node

          if label_or_node.kind_of? GraphNode
            if label_or_node.graph == self
              label_or_node
            elsif raise_error
              raise "Node '#{label_or_node}' does not belong to this graph."
            end
          else
            if include? label_or_node
              node label_or_node
            elsif raise_error
              raise "Node '#{label_or_node}' does not exist."
            end
          end
        end
      end

      class GraphNode
        attr_reader :graph, :label

        def initialize(graph, label)
          @graph = graph
          @label = label

          @incoming = Hash.new
          @outgoing = Hash.new
        end

        def incoming_nodes; @incoming.keys; end
        def outgoing_nodes; @outgoing.keys; end

        def incoming_edges; @incoming.values; end
        def outgoing_edges; @outgoing.values; end

        def incoming_edge(source); @incoming[source]; end
        def outgoing_edge(target); @outgoing[target]; end

        def has_incoming_edges?; @incoming.size > 0; end
        def has_outgoing_edges?; @outgoing.size > 0; end

        def add_incoming_edge(edge)
          raise "Failed to add incoming edge to '#{self}' because edge target is '#{edge.target}'." unless edge.target == self
          unless @incoming.include? edge.source
            @incoming[edge.source] = edge
            edge.source.add_outgoing_edge edge
          end
        end

        def delete_incoming_edge(edge)
          raise "Failed to delete incoming edge to '#{self}' because edge target is '#{edge.target}'." unless edge.target == self
          if @incoming.include? edge.source
            @incoming.delete edge.source
            edge.source.delete_outgoing_edge edge
          end
        end

        def add_outgoing_edge(edge)
          raise "Failed to add outgoing edge to '#{self}' because edge source is '#{edge.source}'." unless edge.source == self
          unless @outgoing.include? edge.target
            @outgoing[edge.target] = edge
            edge.target.add_incoming_edge edge
          end
        end

        def delete_outgoing_edge(edge)
          raise "Failed to delete outgoing edge to '#{self}' because edge source is '#{edge.source}'." unless edge.source == self
          if @outgoing.include? edge.target
            @outgoing.delete edge.target
            edge.target.delete_incoming_edge edge
          end
        end

        def inspect; to_s; end
        def to_s
          @label.to_s
        end
      end

      class GraphEdge
        attr_reader :source, :target, :label

        def initialize(source, target, label)
          @source = source
          @target = target
          @label = label
        end

        #TODO override == and eql?

        def inspect; to_s; end
        def to_s
          "#{source}-#{label}->#{target}"
        end
      end
    end
  end
end