require_relative '../../../lib/citac/utils/graph'
require 'rspec'

describe Citac::Utils::Graphs::Graph do
  before :each do
    @graph = Citac::Utils::Graphs::Graph.new
  end

  describe '#add_node' do
    before :each do
      @return_value = @graph.add_node 1
    end

    it 'should include node' do
      expect(@graph).to include(1)
    end

    it 'should get node' do
      node = @graph.node 1

      expect(node).to_not be_nil
      expect(node.label).to eq(1)
      expect(node.graph).to eq(@graph)
    end

    it 'should contain node in list of nodes' do
      nodes = @graph.nodes
      expect(nodes.size).to eq(1)
      expect(nodes.first).to eq(@graph.node(1))
    end

    it 'should not allow adding a node with the same label again' do
      expect {@graph.add_node(1)}.to raise_error
      expect(@graph.nodes.size).to eq(1)
    end

    it 'should return node' do
      expect(@return_value).to eq(@graph.node(1))
    end
  end

  describe '#node' do
    it 'should return nil if no node with the specified label exists' do
      expect(@graph.node(1)).to be_nil
    end

    it 'should return node object for node with corresponding label' do
      @graph.add_node 1
      node = @graph.node 1

      expect(node).to_not be_nil
      expect(node.label).to eq(1)
      expect(node.graph).to eq(@graph)
    end
  end

  describe '#[]' do
    it 'should return nil if no node with the specified label exists' do
      expect(@graph[1]).to be_nil
    end

    it 'should return node object for node with corresponding label' do
      @graph.add_node 1
      node = @graph[1]

      expect(node).to_not be_nil
      expect(node.label).to eq(1)
      expect(node.graph).to eq(@graph)
    end
  end

  describe '#nodes' do
    it 'should return no nodes if graph is empty' do
      expect(@graph.nodes).to be_empty
    end

    it 'should return single node' do
      @graph.add_node 1

      nodes = @graph.nodes
      expect(nodes.size).to eq(1)
      expect(nodes.first).to eq(@graph[1])
    end

    it 'should return multiple nodes' do
      @graph.add_node 1
      @graph.add_node 2

      nodes = @graph.nodes
      expect(nodes).to contain_exactly(@graph[1], @graph[2])
    end
  end

  describe '#include?' do
    it 'should return false if no node has the label' do
      expect(@graph.include?(1)).to be_falsey
    end

    it 'should return true if there exists a node which has the label' do
      @graph.add_node 1
      expect(@graph.include?(1)).to be_truthy
    end
  end

  describe '#add_edge' do
    before :each do
      @node1 = @graph.add_node 1
      @node2 = @graph.add_node 2
    end

    context 'using node labels' do
      it 'should add edge between two nodes' do
        @graph.add_edge 1, 2

        expect(@node1.outgoing_nodes).to contain_exactly(@node2)
        expect(@node2.incoming_nodes).to contain_exactly(@node1)
      end

      it 'should add edge between two nodes with label' do
        @graph.add_edge 1, 2, '1234'
        edge = @graph.edge 1, 2

        expect(@node1.outgoing_nodes).to contain_exactly(@node2)
        expect(@node2.incoming_nodes).to contain_exactly(@node1)
        expect(edge.label).to eq('1234')
      end

      it 'should not add an already existing edge a second time' do
        @graph.add_edge 1, 2
        @graph.add_edge 1, 2

        expect(@node1.outgoing_nodes).to contain_exactly(@node2)
        expect(@node2.incoming_nodes).to contain_exactly(@node1)
      end

      it 'should add edge to the same node' do
        @graph.add_edge 1, 1

        expect(@node1.outgoing_nodes).to contain_exactly(@node1)
        expect(@node1.incoming_nodes).to contain_exactly(@node1)
      end

      it 'should raise error when trying to add edge with non existing source node' do
        expect{@graph.add_edge 0, 2}.to raise_error
        expect(@node2.incoming_nodes).to be_empty
      end

      it 'should raise error when trying to add edge with non existing destination node' do
        expect{@graph.add_edge 1, 0}.to raise_error
        expect(@node1.outgoing_nodes).to be_empty
      end
    end

    context 'using node objects' do
      it 'should add edge between two nodes' do
        @graph.add_edge @node1, @node2

        expect(@node1.outgoing_nodes).to contain_exactly(@node2)
        expect(@node2.incoming_nodes).to contain_exactly(@node1)
      end

      it 'should add edge between two nodes with label' do
        @graph.add_edge @node1, @node2, '1234'
        edge = @graph.edge @node1, @node2

        expect(@node1.outgoing_nodes).to contain_exactly(@node2)
        expect(@node2.incoming_nodes).to contain_exactly(@node1)
        expect(edge.label).to eq('1234')
      end

      it 'should not add an already existing edge a second time' do
        @graph.add_edge @node1, @node2
        @graph.add_edge @node1, @node2

        expect(@node1.outgoing_nodes).to contain_exactly(@node2)
        expect(@node2.incoming_nodes).to contain_exactly(@node1)
      end

      it 'should add edge to the same node' do
        @graph.add_edge @node1, @node1

        expect(@node1.outgoing_nodes).to contain_exactly(@node1)
        expect(@node1.incoming_nodes).to contain_exactly(@node1)
      end

      it 'should raise error when trying to add edge with non existing source node' do
        expect{@graph.add_edge nil, @node2}.to raise_error
        expect(@node2.incoming_nodes).to be_empty
      end

      it 'should raise error when trying to add edge with non existing destination node' do
        expect{@graph.add_edge @node1, nil}.to raise_error
        expect(@node1.outgoing_nodes).to be_empty
      end
    end
  end

  describe '#calculate_reaching_nodes' do
    before :each do
      # 1 -> 2 -> 3
      # |         ^
      # + - - - - +

      @graph.add_node 1
      @graph.add_node 2
      @graph.add_node 3

      @graph.add_edge 1, 2
      @graph.add_edge 1, 3
      @graph.add_edge 2, 3
    end

    it 'should calculate all nodes which can reach 3' do
      nodes = @graph.calculate_reaching_nodes 3
      nodes.map! {|n| n.label}

      expect(nodes.size).to eq(3)
      expect(nodes).to contain_exactly(1, 2, 3)
    end

    it 'should calculate all nodes which can reach 2' do
      nodes = @graph.calculate_reaching_nodes 2
      nodes.map! {|n| n.label}

      expect(nodes.size).to eq(2)
      expect(nodes).to contain_exactly(1, 2)
    end
  end

  describe '#calculate_reachable_nodes' do
    before :each do
      # 1 -> 2 -> 3
      # |         ^
      # + - - - - +

      @graph.add_node 1
      @graph.add_node 2
      @graph.add_node 3

      @graph.add_edge 1, 2
      @graph.add_edge 1, 3
      @graph.add_edge 2, 3
    end

    it 'should calculate all nodes reachable by 3' do
      nodes = @graph.calculate_reachable_nodes 1
      nodes.map! {|n| n.label}

      expect(nodes.size).to eq(3)
      expect(nodes).to contain_exactly(1, 2, 3)
    end

    it 'should calculate all nodes reachable by 2' do
      nodes = @graph.calculate_reachable_nodes 2
      nodes.map! {|n| n.label}

      expect(nodes.size).to eq(2)
      expect(nodes).to contain_exactly(2, 3)
    end
  end

  describe '#each_path' do
    context 'with single path' do
      before :each do
        @graph.add_node 1
        @graph.add_node 2
        @graph.add_node 3

        @graph.add_edge 1, 2
        @graph.add_edge 2, 3

        @paths = []
        @graph.each_path 1, 3 do |p|
          @paths << p.map(&:label).to_a
        end
      end

      it 'should contain path' do
        expect(@paths).to include([1, 2, 3])
      end

      it 'should contain only one path' do
        expect(@paths.size).to eq(1)
      end
    end

    context 'with single path and dead end' do
      before :each do
        @graph.add_node 1
        @graph.add_node 2
        @graph.add_node 3
        @graph.add_node 4

        @graph.add_edge 1, 2
        @graph.add_edge 1, 4
        @graph.add_edge 2, 3

        @paths = []
        @graph.each_path 1, 3 do |p|
          @paths << p.map(&:label).to_a
        end
      end

      it 'should contain path' do
        expect(@paths).to include([1,2,3])
      end

      it 'should contain only one path' do
        expect(@paths.size).to eq(1)
      end
    end

    context 'with multiple paths' do
      before :each do
        @graph.add_node 1
        @graph.add_node 2
        @graph.add_node 3
        @graph.add_node 4

        @graph.add_edge 1, 2
        @graph.add_edge 1, 4
        @graph.add_edge 2, 3
        @graph.add_edge 4, 3

        @paths = []
        @graph.each_path 1, 3 do |p|
          @paths << p.map(&:label).to_a
        end
      end

      it 'should contain path 1->2->3' do
        expect(@paths).to include([1,2,3])
      end

      it 'should contain path 1->4->3' do
        expect(@paths).to include([1,4,3])
      end

      it 'should contain only two paths' do
        expect(@paths.size).to eq(2)
      end
    end

    context 'with loops in paths' do
      before :each do
        @graph.add_node 1
        @graph.add_node 2
        @graph.add_node 3
        @graph.add_node 4

        @graph.add_edge 1, 2
        @graph.add_edge 1, 4
        @graph.add_edge 2, 3
        @graph.add_edge 4, 1

        @paths = []
        @graph.each_path 1, 3 do |p|
          @paths << p.map(&:label).to_a
        end
      end

      it 'should contain path 1->2->3' do
        expect(@paths).to include([1,2,3])
      end

      it 'should contain only one path' do
        expect(@paths.size).to eq(1)
      end
    end
  end

  describe '#to_graphml' do
    it 'should generate parsable GraphML' do
      @graph.add_node ' My Node 1 '
      @graph.add_node 'My Node 2'
      @graph.add_node 'My Node 3 '

      @graph.add_edge ' My Node 1 ', 'My Node 2', 'asd'
      @graph.add_edge ' My Node 1 ', 'My Node 3 '
      output = @graph.to_graphml

      new_graph = Citac::Utils::Graphs::Graph.from_graphml output
      expect(new_graph).to include(' My Node 1 ')
      expect(new_graph).to include('My Node 2')
      expect(new_graph).to include('My Node 3 ')
      expect(new_graph.nodes.size).to eq(3)

      expect(new_graph.edges.size).to eq(2)

      edge = new_graph.edge ' My Node 1 ', 'My Node 2'
      expect(edge.label).to eq('asd')

      edge = new_graph.edge ' My Node 1 ', 'My Node 3 '
      expect(edge.label).to be_nil
    end
  end

  describe '#delete_edge' do
    before :each do
      @graph.add_node 1
      @graph.add_node 2

      @graph.add_edge 1, 2
    end

    context 'called with nodes' do
      before :each do
        @graph.delete_edge 1, 2
      end

      it 'should delete edge from graph' do
        expect(@graph.edges).to be_empty
      end

      it 'should delete outgoing edge from source node' do
        source = @graph.node 1
        expect(source.outgoing_edges).to be_empty
      end

      it 'should delete incoming edge from target node' do
        target = @graph.node 2
        expect(target.outgoing_edges).to be_empty
      end
    end

    context 'called with edge' do
      before :each do
        @graph.delete_edge @graph.edge(1, 2)
      end

      it 'should delete edge from graph' do
        expect(@graph.edges).to be_empty
      end

      it 'should delete outgoing edge from source node' do
        source = @graph.node 1
        expect(source.outgoing_edges).to be_empty
      end

      it 'should delete incoming edge from target node' do
        target = @graph.node 2
        expect(target.outgoing_edges).to be_empty
      end
    end
  end

  describe '#delete_node' do
    before :each do
      @graph.add_node 1
      @graph.add_node 2
      @graph.add_node 3

      @graph.add_edge 1, 2
    end

    context 'with node without edges' do
      before :each do
        @graph.delete_node 3
      end

      it 'should delete node from graph' do
        expect(@graph).to_not include(3)
      end
    end

    context 'with node with outgoing edge' do
      context 'with edge deletion disabled' do
        it 'should raise error when deleting node' do
          expect{@graph.delete_node 1}.to raise_error
        end

        it 'should keep node' do
          begin; @graph.delete_node 1; rescue; end
          expect(@graph).to include(1)
        end

        it 'should keep edge' do
          begin; @graph.delete_node 1; rescue; end
          expect(@graph.edge(1, 2)).to_not be_nil
        end
      end

      context 'with edge deletion enabled' do
        before :each do
          @graph.delete_node 1, true
        end

        it 'should delete node from graph' do
          expect(@graph).to_not include(1)
        end

        it 'should delete edge from target' do
          node = @graph.node 2
          expect(node.incoming_edges).to be_empty
        end
      end
    end

    context 'with node with incoming edge' do
      context 'with edge deletion disabled' do
        it 'should raise error when deleting node' do
          expect{@graph.delete_node 2}.to raise_error
        end

        it 'should keep node' do
          begin; @graph.delete_node 2; rescue; end
          expect(@graph).to include(2)
        end

        it 'should keep edge' do
          begin; @graph.delete_node 2; rescue; end
          expect(@graph.edge(1, 2)).to_not be_nil
        end
      end

      context 'with edge deletion enabled' do
        before :each do
          @graph.delete_node 2, true
        end

        it 'should delete node from graph' do
          expect(@graph).to_not include(2)
        end

        it 'should delete edge from target' do
          node = @graph.node 1
          expect(node.outgoing_edges).to be_empty
        end
      end
    end

    context 'with non existing node' do
      it 'should not raise error' do
        expect{@graph.delete_node 123}.to_not raise_error
      end
    end
  end

  describe '#cyclic?' do
    context 'with acyclic graph' do
      before :each do
        @graph.add_node 1
        @graph.add_node 2
        @graph.add_node 3

        @graph.add_edge 1, 2
        @graph.add_edge 1, 3
        @graph.add_edge 2, 3
      end

      it 'should determine that graph is acyclic' do
        expect(@graph.cyclic?).to be_falsey
      end
    end

    context 'with cyclic graph' do
      before :each do
        @graph.add_node 1
        @graph.add_node 2
        @graph.add_node 3

        @graph.add_edge 1, 2
        @graph.add_edge 1, 3
        @graph.add_edge 3, 1
      end

      it 'should determine that graph is cyclic' do
        expect(@graph.cyclic?).to be_truthy
      end
    end
  end

  describe '#toposort' do
    it 'should sort graph topologically' do
      @graph.add_node 1
      @graph.add_node 2
      @graph.add_node 3

      @graph.add_edge 1, 2
      @graph.add_edge 1, 3
      @graph.add_edge 2, 3

      order = @graph.toposort.map(&:label).to_a
      expect(order).to eq([1, 2, 3])
    end

    it 'should return nil if graph cannot be sorted topologically' do
      @graph.add_node 1
      @graph.add_node 2
      @graph.add_node 3

      @graph.add_edge 1, 2
      @graph.add_edge 2, 3
      @graph.add_edge 3, 1

      order = @graph.toposort
      expect(order).to be_nil
    end
  end
end