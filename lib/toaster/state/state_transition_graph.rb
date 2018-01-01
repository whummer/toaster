

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/state/state_node"
require "toaster/state/transition_edge"
require "toaster/test/test_coverage"
require "toaster/util/timestamp"
require "toaster/test/test_coverage"
require "toaster/util/combinatorial"
require "toaster/markup/markup_util"

module Toaster

  class StateTransitionGraph

    attr_reader :start_node, :end_node, :nodes, :edges, 
      :tasks, :task_executions, :ignore_properties
    attr_accessor :avoid_circles

    META_PROPERTIES = ["__task_num__", "__original__", "__combo__"]

    def initialize 
      @start_node = StateNodeInitial.new
      @end_node = StateNodeFinal.new
      @tasks = []
      @ignore_properties = []
      @task_executions = {}
      # set of all nodes
      @nodes = Set.new
      # set of nodes without start nodes and end nodes
      @nodes_without_terminals = Set.new
      # set of all edges
      @edges = Set.new
      # set of edges which connect "actual" state nodes, i.e.,
      # not including edges containing a start node or end node
      @edges_without_terminal_nodes = Set.new
      # avoid circles in the generated graph..?
      @avoid_circles = false
    end

    def connect(node1, node2, conditions=nil, transition=nil)
      edge = TransitionEdge.new(node1, node2, conditions, transition)
      @edges.add(edge)
      if node1.succeeding_task
        @edges_without_terminal_nodes.add(edge)
      end
      node1.outgoing.add(edge)
      node2.incoming.add(edge)
    end

    def edges(include_start_and_end_nodes=false)
      return @edges if include_start_and_end_nodes
      return @edges_without_terminal_nodes
    end

    def nodes(include_terminal_nodes=false)
      return @nodes if include_terminal_nodes
      return @nodes_without_terminals
    end

    def get_state(state_props)
      return nil if !state_props
      # remove ignored properties from map
      remove_ignore_props(state_props)
      hash_code = state_props.hash
      # search for existing node
      @nodes_without_terminals.each do |n|
        # first compare hash code
        if hash_code == n.properties.hash
          # now compare actual properties
          if n.properties.eql?(state_props)
            return n
          end
        end
      end
      return add_state(state_props)
    end

    def add_state(state_props)
      n = StateNode.new(state_props)
      @nodes.add(n)
      @nodes_without_terminals.add(n)
      return n
    end

    def self.build_graph_for_test_suite(test_suite)
      return build_graph_for_automation(test_suite.automation, test_suite.coverage_goal)
    end

    def self.build_graph_for_automation(automation, coverage_goal=nil)
      coverage_goal = TestCoverageGoal.new if !coverage_goal

      if !automation
        raise "Cannot build graph for nil automation."
      end

      ignore_properties = []
      # dup here to avoid updates of active record
      ignore_properties.concat(automation.ignore_properties.to_a.dup)
      additional_ignores = SystemState.read_ignore_properties()
      additional_ignores = [] if !additional_ignores
      ignore_properties.concat(additional_ignores)
      puts "DEBUG: ignore_properties: #{ignore_properties}"

      # list of tasks
      TimeStamp.add(nil, "get_tasks")
      tasks = automation.get_globally_executed_tasks
      TimeStamp.add_and_print("load automation tasks", nil, "get_tasks")
      # let's make sure the list of tasks is index-based (i.e., not a Set)
      # (because we want to do index-based lookaheads in the tasks array later on..)
      tasks = tasks.to_a
      # STG instance
      graph = build_graph_for_tasks(tasks, coverage_goal, ignore_properties)

      return graph
    end

    def self.build_graph_for_tasks(tasks, coverage_goal=nil, ignore_properties=[])
      coverage_goal = TestCoverageGoal.new if !coverage_goal

      TimeStamp.add(nil, "build_graph")
      graph = StateTransitionGraph.new()
      graph.avoid_circles = coverage_goal.repeat_N.to_i >= 0
      graph.ignore_properties.concat(ignore_properties)
      graph.tasks.concat(tasks)
      tasks.each do |t|
        t.global_executions.each do |exe|
          if exe.success
            graph.task_executions[t] = [] if !graph.task_executions[t]
            graph.task_executions[t] << exe
          end
        end
      end
      TimeStamp.add_and_print("load task executions for list of #{tasks.size} tasks.", nil, "build_graph")

      TimeStamp.add(nil, "build_graph_states")
      graph.build_states_for_task_executions()
      TimeStamp.add_and_print("build states from task executions", nil, "build_graph_states")

      idem_numtasks = coverage_goal.idempotence
      if idem_numtasks
        idem_numtasks = [idem_numtasks] if !idem_numtasks.kind_of?(Array)
        TimeStamp.add(nil, "extend_idem")
        idem_numtasks.each do |idem|
          if tasks.size >= idem
            graph.extend_for_idempodence(idem, coverage_goal.only_connect_to_start)
          end
        end
        TimeStamp.add_and_print("extend graph for idempotence", nil, "extend_idem")
      end

      TimeStamp.add(nil, "extend_comb")
      coverage_goal.combinations.each do |type,lengths|
        if type == CombinationCoverage::COMBINE_N
          lengths.each do |n|
            graph.extend_for_combinations(n, false)
          end
        elsif type == CombinationCoverage::COMBINE_N_SUCCESSIVE
          lengths.each do |n|
            graph.extend_for_combinations(n, true)
          end
        elsif type == CombinationCoverage::SKIP_N
          lengths.each do |n|
            graph.extend_for_skippings(n, false)
          end
        elsif type == CombinationCoverage::SKIP_N_SUCCESSIVE
          lengths.each do |n|
            graph.extend_for_skippings(n, true)
          end
        end
      end
      TimeStamp.add_and_print("extend graph for combinations", nil, "extend_comb")

      return graph
    end

    #
    # Build the basic graph nodes as a permutation over 
    # the pre-states and post-states of task executions 
    # monitored by the system.
    #
    def build_states_for_task_executions(insert_nil_prestate_prop_for_insertions=false)

      # node front, i.e., list of temporary child nodes as 
      # we iterate through the tasks and build the graph
      node_front = [start_node()]

      count = 0

      puts "INFO: Building graph states for #{tasks.size} tasks."

      # nested loop 1
      tasks.each do |t|
        count += 1

        #puts "INFO: Handling task ##{count} of #{tasks.size}. Node front size: #{node_front.size}"

        execs = task_executions[t]

        # initialize the hash with a single element that 
        # represents an "empty pre-state" with an "empty set of conditions". 
        # This makes sure that we always execute the innermost
        # loop at least once, which is actually only relevant
        # for the last task which has no "next pre-states"...
        trans_next_desired_pre_states = {
                                  {} => Set.new
                                }

        # make a look-ahead to the pre-states of the next task in our sequence
        if count < tasks.size
          t_next = tasks[count]
          execs_next = task_executions[t_next]
          transitions_next = t_next.global_state_transitions(execs_next, insert_nil_prestate_prop_for_insertions)
          # insert artificial transition, for automations which have not been executed before
          if transitions_next.empty?
            transitions_next << StateTransition.new
          end
          trans_next_desired_pre_states = StateTransitionGraph.prestates_from_transitions(transitions_next)
        end
        #puts "trans_next_desired_pre_states size: #{trans_next_desired_pre_states.size}"

        transitions = t.global_state_transitions(execs, insert_nil_prestate_prop_for_insertions)
        # insert artificial transition, for automations which have not been executed before
        if transitions.empty?
          transitions << StateTransition.new
        end
        prestates = t.global_pre_states_reduced(transitions)
        desired_prestates_in_tests = prestates

        log "desired_prestates_in_tests #{desired_prestates_in_tests.inspect}"

        # are we handling the first task?
        if count == 1
          desired_prestates_in_tests.each do |pre|
            # remove ignored properties
            remove_ignore_props(pre)
            # artificially introduce __task_num__ parameter, because
            # we want to obtain a nice, cycle-free "left-to-right" 
            # graph that grows as we iterate through the tasks
            n = get_state(pre.merge({"__task_num__" => count-1, "__original__" => true}))
            n.succeeding_task = t
            connect(start_node, n)
            node_front << n
          end
          node_front.delete(start_node())
        end

        # copy and clear node front list
        node_front_copy = node_front
        node_front = []

        trans_post_states = StateTransitionGraph.poststates_from_transitions(transitions)

        # nested loop 2
        trans_post_states.each do |post,trans_conditions|

          # Since post states are determined from the state changes
          # of state transitions, we might get into a situation where 
          # the repeated execution of a task (because we test idempotence) 
          # does not result in any state changes and hence we receive an
          # empty post state... 
          # This would be incorrect and would blow up our STG!
          # Hence, we only continue here if either
          # - the post state is not empty, OR
          # - there is only one (probably empty) post state
          if !post.empty? || trans_post_states.size == 1

            # remove ignored properties
            remove_ignore_props(post)

            # nested loop 3
            node_front_copy.each do |node|

              # nested loop 4
              trans_next_desired_pre_states.each do |pre_next,trans_conditions_next|

                new_state = {}
                StateTransitionGraph.state_merge!(new_state, node.properties)
                StateTransitionGraph.state_merge!(new_state, pre_next)
                StateTransitionGraph.state_merge!(new_state, post)
                # again, additionally introduce __task_num__ parameter
                StateTransitionGraph.state_merge!(new_state, {"__task_num__" => count, "__original__" => true})

                n = get_state(new_state)

                n.preceding_task = t
                if count < tasks.size
                  n.succeeding_task = tasks[count]
                end

                connect(node, n, trans_conditions)
                if !node_front.include?(n) && StateTransitionGraph.node_satisfies_poststate(n, post)
                  node_front << n
                end

              end

            end

          end

        end

        # are we handling the last task?
        if count >= tasks.size
          node_front.each do |n|
            connect(n, end_node())
          end
        end

      end

      return self
    end

    #
    # Add graph nodes and edges to satisfy the 
    # idempotence test coverage criterion for 
    # a given number of tasks.
    #
    def extend_for_idempodence(num_tasks, only_connect_to_start=true)

      nodes_before = @nodes_without_terminals.size
      puts "DEBUG: Extending graph with #{nodes_before} nodes " +
        "for idempotence of length=#{num_tasks}, only_connect_to_start=#{only_connect_to_start}"
      @nodes_without_terminals.dup.each do |n|
        if original_node?(n)
          if n.succeeding_task
            task_index = tasks.index(n.succeeding_task)
            if !only_connect_to_start || task_index == num_tasks
              connect_to_matching_prestate(n, num_tasks - 1)
            end
          else
            task_index = tasks.index(n.preceding_task) + 1
            if !only_connect_to_start || task_index == num_tasks
              #puts "DEBUG: Connecting node #{n} to matching prestate, num_tasks=#{num_tasks}"
              connect_to_matching_prestate(n, num_tasks - 1)
            end
          end
        end
      end
      nodes_after = @nodes_without_terminals.size

    end

    def connect_to_matching_prestate(node, num_tasks_back)
      preceding_task = get_preceding_task(node, num_tasks_back)
      
      if preceding_task

        prestate_node = nil

        if !@avoid_circles
          # find non-conflicting pre-state for this post-state
          prestates = prestate_nodes_of_task(preceding_task)
          non_conflicting_node = nil
          prestates.each do |pre|
            if !pre.conflicts_with?(node, META_PROPERTIES)
              non_conflicting_node = pre
              break
            end
          end
          prestate_node = non_conflicting_node
        else
          # always create a new state node
          prestate_node = nil
        end

        is_new_node = false
        if !prestate_node
          state_props = node.properties.dup
          # decrease property "__task_num__"
          state_props["__task_num__"] -= num_tasks_back + 1
          # remove property "__original__"
          state_props.delete("__original__")
          prestate_node = add_state(state_props)
          prestate_node.succeeding_task = preceding_task
          prestate_node.preceding_task = nil
          is_new_node = true
          #connect_to_prestate_recursively(new_node)
        end

        #connect node to new node
        connect(node, prestate_node, nil)

        # connect new node to successor node (recursively)
        if is_new_node
          connect_to_successor_recursive(prestate_node) 
        end
        #end

      else
        # connect to start_node
        # TODO needed?
        #connect(@start_node, node, nil)
      end

    end

    def connect_to_successor_recursive(node, consider_task_convergence=false)
      next_task = node.succeeding_task
      # find non-conflicting pre-state of the next task
      states = poststate_nodes_of_task(next_task)
      non_conflicting_node = nil
      if !@avoid_circles
        states.each do |state|
          if !state.conflicts_with?(node, META_PROPERTIES)
            non_conflicting_node = state
            break
          end
        end
      end
      # connect to new node
      if non_conflicting_node
        connect(node, non_conflicting_node)
      else
        state_props = node.properties.dup
        # increase property "__task_num__" by 1
        state_props["__task_num__"] += 1
        # remove property "__original__"
        state_props.delete("__original__")

        if consider_task_convergence
          # TODO needed?
          raise "not implemented"
          # add properties which represent the state change of the task execution
          #execs = task_executions[next_task]
          #transitions = next_task.global_state_transitions(execs)
          #poststates = next_task.global_post_states_reduced(transitions)
          #state_props.merge!(poststates)
        end

        new_node = add_state(state_props)
        new_node.preceding_task = node.succeeding_task
        new_node.succeeding_task = get_task_after(node.succeeding_task)
        #connect node to new node
        connect(node, new_node)

        if new_node.succeeding_task
          connect_to_successor_recursive(new_node)
        else
          connect(new_node, @end_node)
        end
      end
    end

    #
    # Add graph nodes and edges to satisfy different task combination
    # test coverage criteria.
    # Args:
    #  - *combination_length*: length of the task combinations to be covered.
    #  - *only_successive*: whether the combinations have to be successive tasks.
    #
    def extend_for_combinations(combination_length, successive=false)
      #puts "INFO generating combinations of length #{combination_length} for list with #{tasks.size} tasks, only_successive=#{successive}"
      combinations = Combinatorial.combine(tasks, combination_length, successive)
      extend_for_combination_set(combinations)
    end

    def extend_for_skippings(combination_length, successive=false)
      #puts "INFO generating 'skippings' of length #{combination_length} for list with #{tasks.size} tasks, only_successive=#{successive}"
      combinations = Combinatorial.skip(tasks, combination_length, successive)
      extend_for_combination_set(combinations)
    end

    def extend_for_combination_set(combinations)

      combinations.each do |combo|

        node_front = [start_node]
        
        combo_id = Util.generate_short_uid()

        combo.each do |task|

          node_front_copy = node_front.dup
          node_front = []

          node_front_copy.each do |node|

            task_prestates = prestate_nodes_of_task_reachable_from_node(task, node)

            task_prestates.each do |prestate_node|

              prestate_node_copy = prestate_node

              if combo.index(task) <= 0
                prestate_node = get_state(prestate_node.properties.merge("__combo__" => combo_id))
              elsif combo.index(task) >= combo.size - 1
                node = get_state(node.properties.merge("__combo__" => combo_id))
              else
                node = get_state(node.properties.merge("__combo__" => combo_id))
                prestate_node = get_state(prestate_node.properties.merge("__combo__" => combo_id))
              end

              connect(node, prestate_node, nil)
              node_front << prestate_node_copy

            end
          end

        end

        # finally, connect all nodes in the "node front" to the end node
        node_front.each do |node|
          connect(node, @end_node, nil)
        end

      end

    end

    def to_simple_json(include_start_and_end_nodes=true)

      if @nodes.size > 1000
        puts "WARN: Graph contains #{@nodes.size} nodes. Aborting request."
        return "{}"
      end

      json = {}
      nodes = (json["nodes"] = [])
      edges = (json["edges"] = [])
      node_ids = {}
      if include_start_and_end_nodes
        node_ids[@start_node] = "__start__"
        node_ids[@end_node] = "__end__"
        nodes << { "ID" => "__start__", "name" => "Start", "column" => 1, "content" => "" }
        nodes << { "ID" => "__end__", "name" => "End", "column" => @tasks.size + 3, "content" => "" }
      end
      counter = 0
      # build list of nodes
      @nodes.each do |n|
        counter += 1
        node_ids[n] = "n#{counter}"
        props = n.properties.dup
        task_num = props["__task_num__"]
        META_PROPERTIES.each do |mp|
          props.delete(mp)
        end
        name = "State #{counter}"
        content = MarkupUtil.to_pretty_json(props)[1..-2].strip
        nodes << { "ID" => node_ids[n], 
            "name" => name,
            "content" => content,
            "column" => task_num + 2
          }
      end
      # build list of edges
      nodes_with_start = @nodes_without_terminals.dup
      nodes_with_start << @start_node
      nodes_with_start.each do |n|
        n.outgoing.each do |e|
          from = node_ids[e.node_from]
          to = node_ids[e.node_to]
          if from && to
            task = e.represented_task
            link = $cgi && task ? l('auto' => '', 'task' => task.id, 't' => 'tasks') : ""
            label = task ? task.name : ""
            label_short = task ? ("t#{@tasks.index(task) + 1}") : ""
            edges << { "from" => from, "to" => to, "href" => link,
                       "label" => label, "label_short" => label_short }
          end
        end
      end
      return MarkupUtil.to_pretty_json(json)
    end

    ##########
    # Private Helper Methods
    ##########

    private

    def original_node?(node)
      return !node.properties["__original__"].nil?
    end

    def remove_ignore_props(state_props)
      SystemState.remove_ignore_props!(state_props, @ignore_properties)
    end

    def get_task_after(task)
      return nil if !task
      return get_task_relative_to(task, 1)
    end

    def get_preceding_task(node, num_tasks_back=1)
      return nil if !node.preceding_task
      return get_task_relative_to(node.preceding_task, -num_tasks_back)
    end
    
    def get_task_relative_to(task, num_tasks_forward_or_back=1)
      index = @tasks.index(task)
      index = index + num_tasks_forward_or_back
      return nil if index < 0
      return @tasks[index]
    end

    def prestate_nodes_of_task(task)
      result = Set.new
      @nodes_without_terminals.each do |n|
        if n.succeeding_task == task
          result << n
        end
      end
      return result
    end

    def prestate_nodes_of_task_reachable_from_node(task, reachable_from_node, result=Set.new, visited_nodes=Set.new)
      if visited_nodes.include?(reachable_from_node)
        # circle detected, return...
        return result
      end
      visited_nodes << reachable_from_node
      reachable_from_node.outgoing.each do |edge|
        n = edge.node_to
        if n.succeeding_task == task
          result << n
        end
        prestate_nodes_of_task_reachable_from_node(task, n, result, visited_nodes)
      end
      return result
    end

    def poststate_nodes_of_task(task)
      result = Set.new
      @nodes_without_terminals.each do |n|
        if n.preceding_task == task
          result << n
        end
      end
      return result
    end

    # Determines for a set of state transitions the distinct post-states, 
    # plus the task parameters which lead to these post-states.
    #
    # * *Args*    :
    #   - +transitions+ -> Set of TaskTransition objects
    # * *Returns* :
    #   a Hash with poststate => [conditions...]
    def self.poststates_from_transitions(transitions)
      result = {}
      transitions.each do |t|
        result[t.post_state] = Set.new if !result[t.post_state]
        result[t.post_state] << t.parameters
      end
      return result
    end
    
    # Determines for a set of state transitions the distinct pre-states, 
    # plus the task parameters which lead to these pre-states.
    #
    # * *Args*    :
    #   - +transitions+ -> Set of TaskTransition objects
    # * *Returns* :
    #   a Hash with prestate => [conditions...]
    def self.prestates_from_transitions(transitions)
      result = {}
      transitions.each do |t|
        result[t.pre_state] = Set.new if !result[t.pre_state]
        result[t.pre_state] << t.parameters
      end
      return result
    end

    def self.states_from_transitions(transitions)
      result = {}
      transitions.each do |t|
        result[t.pre_state] = Set.new if !result[t.pre_state]
        result[t.pre_state] << t.parameters
        result[t.post_state] = Set.new if !result[t.post_state]
        result[t.post_state] << t.parameters
      end
      return result
    end

    def self.node_satisfies_poststate(node, post)
      return node.satisfies_poststate(post)
    end

    def self.state_merge(state1, state2)
      state1.merge(state2)
    end
    def self.state_merge!(state1, state2)
      state1.merge!(state2)
    end

    def self.log(msg)
      #puts msg
    end
    def log(msg)
      self.class.log msg
    end

  end

end
