

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/state/transition_edge"
require "toaster/markup/markup_util"

include Toaster

module Toaster

  class StateNode
    attr_reader :properties, :incoming, :outgoing
    attr_accessor :preceding_task, :succeeding_task

    def initialize(properties = {})
      @properties = properties
      @incoming = Set.new
      @outgoing = Set.new
      @preceding_task = nil
      @succeeding_task = nil
      @reachable_nodes = nil
    end

    # determine whether the state properties of this node are a 
    # subset of (or equal to) the properties of the given state
    def subset_of?(state, ignore_properties=[])
      @properties.each do |prop,val|
        if !ignore_properties.include?(prop)
          val1 = MarkupUtil.get_value_by_path(state, prop, true)
          contained = (val1 == val || val1.eql?(val))
          if !contained
            #puts "property '#{prop}'='#{val}' is not contained in state hash with #{state.size} properties"
            #puts "property '#{prop}'='#{val}' is not contained in #{state.inspect}"
          else
            #puts "'#{prop}'='#{val}' IS contained in state"
          end
          return false if !contained
        end
      end
      return true
    end

    def conflicts_with?(node, ignore_properties=[])
      return !subset_of?(node.properties, ignore_properties) && 
              !node.subset_of?(properties, ignore_properties)
    end

    def state_merge(additional_new_state)
      @properties.merge(additional_new_state)
    end

    def satisfies_poststate(post)
      post.each do |key,value|
        if @properties[key] != value
          return false
        end
      end
      return true
    end

    def self.state_merge(old_node, additional_new_state)
      return old_node.state_merge(additional_new_state)
    end

    def reachable?(node, check_cycles=true)
      return node_reachable?(node, check_cycles)
    end

    def node_reachable?(node, check_cycles=true, nodes_visited=Set.new)
      return reachable_nodes().include?(node)
    end

    def reachable_nodes()
      return @reachable_nodes if @reachable_nodes
      @reachable_nodes = get_reachable_nodes()
      return @reachable_nodes
    end

    def get_reachable_nodes(nodes_so_far=Set.new)
      stack = [self]
      while !stack.empty?
        node = stack.delete_at(0)
        if !nodes_so_far.include?(node)
          nodes_so_far << node
          node.outgoing.each do |edge|
            next_node = edge.node_to
            stack << next_node
            #next_node.get_reachable_nodes(nodes_so_far)
          end
        end
      end
      return nodes_so_far
    end

  end

  class StateNodeInitial < StateNode
  end
  class StateNodeFinal < StateNode
  end

end
