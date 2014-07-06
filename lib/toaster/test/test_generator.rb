

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/state/state_transition_graph"
require "toaster/test/test_coverage"
require "toaster/test/test_case"

include Toaster

module Toaster
  class TestGenerator

    attr_accessor :test_suite, :state_graph

    def initialize(test_suite, state_graph = nil)
      @state_graph = state_graph
      @test_suite = test_suite
      @automation = test_suite.automation
      if !state_graph
        @state_graph = StateTransitionGraph.build_graph_for_test_suite(@test_suite)
      end
      @coverage = TestCoverage.new(@test_suite, @state_graph)
    end

    def default_test_case()
      c = TestCase.new(:test_suite => @test_suite)
      return c
    end

    def gen_test_each_task(exclude_self=false)
      result = []

      tasks = @automation.tasks
      # remove tasks that are related to the Chef instrumentation 
      # performed by the Testing framework
      tasks = tasks.select{ |t| !t.toaster_testing_task? }

      tasks.each do |t|

        parameter_combinations = gen_param_combinations(t.parameters)
        puts "INFO: generated #{parameter_combinations.size} parameter combinations: #{parameter_combinations.inspect}"

        parameter_combinations.each do |params|
          c = TestCase.new(:test_suite => @test_suite)
          skip_tasks = tasks.select{ |t1| exclude_self ? t1.uuid == t.uuid : t1.uuid != t.uuid }
          skip_task_uuids = skip_tasks.collect{ |t1| t1.uuid }
          c.skip_task_uuids.concat(skip_task_uuids)
          c.test_attributes.merge(params)
          if !result.include?(c) && !test_executed?(c)
            result << c
          end
        end
      end

      return result
    end

    def gen_param_combinations(all_params, current={}, result=Set.new)
      if all_params.empty?
        result << current
        return result
      end
      all_params_new = all_params.dup
      this_param = all_params_new[0]
      all_params_new.delete(this_param)
      key = this_param.key

      @test_suite.parameter_test_values[key].each do |val|
        new_cur = current.clone()
        new_cur[key] = val
        gen_param_combinations(all_params_new, new_cur, result)
      end
      
      return result
    end

    def gen_test_exclude_each_task()
      gen_test_each_task(true)
    end

    def gen_all_tests()
      cvg_goal = @test_suite.coverage_goal
      if cvg_goal.graph == StateGraphCoverage::STATES
        return gen_test_each_state()
      elsif cvg_goal.graph == StateGraphCoverage::TRANSITIONS
        return gen_test_each_transition()
      end
      puts "WARN: Coverage goal should be either STATES or TRANSITIONS."
      return []
    end

    def gen_test_each_state(max_node_occurrences=2)
      result = []
      all_states = state_graph.nodes
      covered_states = Set.new
      covered_states << @state_graph.start_node
      problem_states = []
      while covered_states.size + problem_states.size < all_states.size
        state_to_cover = (all_states - problem_states - covered_states).to_a[0]
        path = do_create_path([state_to_cover], max_node_occurrences)
        if !path
          puts "INFO: problem state detected: #{state_to_cover}"
          state_to_cover.outgoing.each do |e|
            #puts "#{state_to_cover} --> #{e.node_to}"
            e.node_to.outgoing.each do |e1|
              #puts "#{e.node_to} ==> #{e1.node_to}"
            end
          end
          state_to_cover.incoming.each do |e|
            #puts "#{e.node_from} ~~> #{state_to_cover}"
          end
          problem_states << state_to_cover
        else
          covered_states.merge(path.collect { |e| e.node_to } )
          tasks = get_task_sequence(path)
          c = TestCase.new(:test_suite => @test_suite)
          #puts "DEBUG: sequence of tasks for test case: #{tasks.collect {|t| t.uuid}}"
          c.repeat_task_uuids = gen_repeat_config(tasks)
          #puts "DEBUG: repeat tasks: #{c.repeat_task_uuids}"
          params = {}
          path.each do |edge|
            # TODO! add parameters!
            #params.merge!(edge.transition.parameters)
          end
          c.test_attributes.concat(RunAttribute.from_hash(params))
          if !result.include?(c) && !test_executed?(c)
            result << c
          end
        end
        #puts "--> #{covered_states.size} of #{all_states.size} states covered by #{result.size} test cases"
      end
      return result
    end

    def gen_test_each_transition()
      result = []
      # TODO
      return result
    end

    private

    def do_create_path(nodes_to_include=[], max_node_occurrences=2,
        path_so_far=[], target_node=@state_graph.end_node, visited=[])

      current_node = path_so_far.empty? ? @state_graph.start_node : path_so_far[-1].node_to

      visited << current_node

      #puts "node #{current_node} - #{path_so_far[-1]} - #{path_so_far[-1].node_from}"
      if current_node.kind_of?(StateNodeFinal) || current_node == target_node
        #puts "nodes_to_include: #{nodes_to_include.size()}"
        return nil if !nodes_to_include.empty? 
        return path_so_far
      end
      puts "WARN: no outgoing edges for node #{current_node}!" if current_node.outgoing.empty?
      current_node.outgoing.each do |edge|
        if visited.count(edge.node_to) < max_node_occurrences
          all_accessible = true
          nodes_to_include.each do |node|
            reachable = nil
            begin 
              reachable = edge.node_to.node_reachable?(node)
            rescue Object => ex
              puts caller.join("\n")
              puts caller.size
              puts visited.size
              raise ex
            end
            #puts "INFO #{node} reachable from #{edge.node_to}: #{reachable} - #{current_node.outgoing.size} - #{visited.size}" if reachable
            if !reachable
              all_accessible = false
              break
            end
          end
          if all_accessible
            path_so_far_copy = path_so_far.dup
            path_so_far_copy << edge
            nodes_to_include_copy = nodes_to_include.dup
            del = nodes_to_include_copy.delete(edge.node_to)
            #puts "INFO: deleted node #{edge.node_to}, pre-task #{@state_graph.tasks.index(edge.represented_task)} from list of nodes to include!" if del
            path = do_create_path(nodes_to_include_copy, max_node_occurrences, path_so_far_copy, target_node, visited.dup)
            return path if path
          end
        end
      end
      #puts "all_visited: #{all_visited.size}"
      #puts "WARN: Looks like not all #{nodes_to_include.size} required nodes are accessible from node #{current_node}"
      return nil
      
      # choose random successor node
      index = rand(current_node.outgoing.size)
      edge = current_node.outgoing.to_a[index]
      path_so_far << edge
      nodes_to_include = nodes_to_include.dup
      nodes_to_include.delete(edge.node_to)
      return do_create_path(nodes_to_include, max_node_occurrences, path_so_far, target_node, visited)
    end

    def get_task_sequence(transition_path)
      seq = (transition_path.select { |e| !e.represented_task.nil? }).collect { |e| e.represented_task }
      #puts "DEBUG: sequence of #{seq.size} tasks extracted from path with #{transition_path.size} transitions"
      return seq
    end

    def test_executed?(test_case)
      return @coverage.test_executed?(test_case)
    end

    def gen_repeat_config(task_list)
      result = []
      index = {}
      i = 0
      while i < task_list.size
        task = task_list[i]
        existing = index[task.uuid]
        index[task.uuid] = i
        if !existing.nil?
          combination = task_list[existing..i-1].collect { |t| t ? t.uuid : nil }
          result << combination
          combination_length = combination.size
          i += combination_length
        else
          i += 1
        end
      end
      return result
    end

    def get_indexes(task, task_list)
      index = 0
      result = []
      task_list.each do |t|
        if task == t || task.eql?(t)
          result << index
        end
        index += 1
      end
      return result
    end

  end
end
