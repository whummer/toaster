

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/util/util"
require "toaster/model/task_execution"
require "toaster/model/task_parameter"
require "toaster/state/state_transition"
require "toaster/state/system_state"

module Toaster
  class Task < ActiveRecord::Base

    has_many :task_parameters, :autosave => true, :dependent => :destroy
    has_many :task_executions, :autosave => true, :dependent => :destroy
    belongs_to :automation

    attr_accessor :resource_obj

    def initialize(attr_hash)
      if !attr_hash[:uuid]
        attr_hash[:uuid] = Util.generate_short_uid()
      end
      super(attr_hash)
    end
  
    def initialize1(resource, action, sourcecode, uuid = nil)
      @db_type = "automation_task"
      @resource = resource ? resource.to_s : nil
      @resource_obj = resource
      @action = action ? action.to_s : nil
      @uuid = uuid ? uuid : Util.generate_short_uid()
      @sourcecode = sourcecode
      @sourcehash = sourcecode ? Util.md5(sourcecode) : nil
      @sourcefile = nil
      @sourceline = 0
      @parameters = []
      @executions_cache = []
    end

    #
    # Return an array of TaskExecution instances for this task.
    #
    def global_executions(criteria={})
      criteria[:task] = self
      return TaskExecution.find(criteria)
    end

    def global_num_executions()
      return global_executions().size
    end
    def global_successful_executions()
      return global_executions(:success => true)
    end
    def global_num_successful_executions()
      return global_successful_executions().size
    end
    def global_success_rate()
      return global_num_successful_executions().to_f / global_num_executions().to_f
    end
    def global_success_percentage()
      return global_num_successful_executions().to_f / global_num_executions().to_f * 100.0
    end

    def set_executions(execs)
      @executions_cache = execs
    end

    #
    # Return an array of lists of StateChange.
    # Length of the array is the number of global executions of this task.
    # For each task execution, the array contains a list with all state
    # changes caused by this execution.
    # 
    def global_state_prop_changes(global_execs = nil)
      return StateChange.joins(:task_execution => :task).where(
        "task_executions.task_id" => self.id)
    end
    def global_num_state_prop_changes(global_executions = nil)
      return global_state_prop_changes(global_executions).size
    end

    #
    # Return a map StateChange -> Integer .
    # This method maps each state property change to the number
    # of occurrences, summed up for all executions of this task.
    #
    def global_state_prop_changes_map(global_execs = nil)
      result = {}
      global_state_prop_changes(global_execs).each do |c|
        result[c] = 0 if !result[c]
        result[c] += 1
      end
      return result
    end

    #
    # Return a set of StateTransition objects for this task. 
    # A StateTransition basically represents a triple (pre-state, parameters, post-state).
    # * pre-state and post-state are maps of state property values {prop_key=>value}.
    # * parameters is a map of input parameter values {param_name=>value}.
    #
    # The result set contains all state transitions that were recorded in
    # any of the executions of this task.
    # 
    # This method is the basis for construction of the state transition graph.
    # 
    def global_state_transitions(global_execs=nil, insert_nil_prestate_prop_for_insertions=false)
      result = Set.new
      global_execs = global_executions() if !global_execs
      global_execs.each do |exe|
        changes = exe.state_changes
        prestate = {}
        changes.each { |c|
          if c.is_delete?
            prestate[c.property] = c.value
          elsif c.is_modify?
            prestate[c.property] = c.old_value
          elsif c.is_insert?
            if insert_nil_prestate_prop_for_insertions
              prestate[c.property] = nil
            end
          end
        }
        poststate = {}
        changes.each { |c| 
          if c.is_delete?
            poststate[c.property] = nil
          elsif c.is_modify? || c.is_insert?
            poststate[c.property] = c.value
          end
        }
        params = exe.get_used_parameters()
        trans = StateTransition.new(prestate, params, poststate)
        result << trans
      end
      return result
    end

    #
    # Return a set of state property mappings {prop_key => value} .
    #
    # The result set contains all states which were observed either as pre-state 
    # or as post-state of any of the executions of this task. The states are
    # reduced to their "relevant" parts, i.e., only those state properties are 
    # included which are inserted/deleted/modified by the task, AND only those 
    # state properties which are not in the list of ignored properties of this 
    # task's automation.
    #
    def global_states_reduced(state_transitions = nil, include_empty_states = true, 
          add_prestates = true, add_poststates = true)
      ignore_props = automation ? automation.ignore_properties.to_a.dup : []
      # add global ignore properties
      ignore_props.concat(SystemState.read_ignore_properties())
      puts "WARN: No automation found for task UUID #{@uuid}!" if !automation
      result = Set.new
      state_transitions = global_state_transitions() if !state_transitions
      state_transitions.each do |t|
        if add_prestates
          SystemState.remove_ignore_props!(t.pre_state, ignore_props)
          if (include_empty_states || !t.pre_state.empty?)
            result << t.pre_state
          end
        end
        if add_poststates
          SystemState.remove_ignore_props!(t.post_state, ignore_props)
          if (include_empty_states || !t.post_state.empty?)
            result << t.post_state
          end
        end
      end
      return result
    end
    def global_pre_states_reduced(state_transitions = nil, include_empty_states = true)
      return global_states_reduced(state_transitions, include_empty_states, true, false)
    end
    def global_post_states_reduced(state_transitions = nil, include_empty_states = true)
      return global_states_reduced(state_transitions, include_empty_states, false, true)
    end

    def global_pre_states(global_execs = nil)
      result = []
      global_execs = global_executions() if !global_execs
      # set list of ignored properties
      ignore_props = automation ? automation.ignore_properties.to_a.dup : []
      ignore_props.concat(SystemState.read_ignore_properties())
      global_execs.each do |exe|
        state = exe.state_before
        # elimination of map entries is required for removing ignore props!
        MarkupUtil.eliminate_inserted_map_entries!(state)
        SystemState.remove_ignore_props!(state, ignore_props) 
        result << state
      end
      return result
    end

    def global_post_states(global_execs = nil)
      result = []
      global_execs = global_executions() if !global_execs
      # set list of ignored properties
      ignore_props = automation ? automation.ignore_properties.to_a.dup : []
      ignore_props.concat(SystemState.read_ignore_properties())
      global_execs.each do |exe|
        state = exe.state_after
        # elimination of map entries is required for removing ignore props!
        MarkupUtil.eliminate_inserted_map_entries!(state)
        SystemState.remove_ignore_props!(state, ignore_props)
        result << state
      end
      return result
    end

    def global_pre_states_flat(global_execs = nil)
      return Task.properties_flat(global_pre_states(global_execs))
    end

    def global_post_states_flat(global_execs = nil)
      return Task.properties_flat(global_post_states(global_execs))
    end

    def self.properties_flat(states_array)
      result = []
      states_array.each do |s|
        MarkupUtil.eliminate_inserted_map_entries!(s)
        s = SystemState.get_flat_attributes(s)
        s.each do |k,v|
          entry = [k,v]
          if !result.include?(entry)
            result << entry
          end
        end
      end
      return result
    end

    def toaster_testing_task?()
      return sourcefile == "toaster/recipes/testing.rb"
    end

    #
    # Returns a hash which maps identifier=>configurations, indicating which types 
    # of state changes this task, upon execution, is *potentially* going to 
    # perform. For instance, if the task starts/stops a system service,
    # the identifier "ports" will be in the hash keys. If the task modifies 
    # some files, the key will contain the identifier "files", and possibly a list of
    # potential files that may be edited. 
    # This helps us to develop tailor-made state capturing tools (e.g., implemented 
    # as ohai plugins) for different types of tasks.
    # 
    def get_config_for_potential_state_changes()
      require "toaster/chef/resource_inspector"
      return ResourceInspector.get_config_for_potential_state_changes(self)
    end

    def guess_potential_state_changes()
      require "toaster/chef/resource_inspector"
      return ResourceInspector.guess_potential_state_changes(self)
    end

    def name
      return "#{resource}::#{action}"
    end

    def self.find(criteria={})
      DB.find_activerecord(Task, criteria)
    end

    def self.load_from_chef_source(resource, action, sourcecode, sourcefile, sourceline)
      sourcecode.strip! if sourcecode.kind_of?(String)
      params = {
        :resource => resource.to_s,
        :action => action,
        :sourcefile => sourcefile,
        :sourceline => sourceline
      }
      task = find_by(params)
      if !task
        params[:sourcecode] = sourcecode
        task = Task.new(params)
      end
      task.resource_obj = resource
      return task
    end

    def eql?(other)
      return other.kind_of?(Task) && !uuid.nil? && uuid == other.uuid
    end

  end
end
