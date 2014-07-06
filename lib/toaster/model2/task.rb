

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/db/mongodb_object"
require "toaster/util/util"
require "toaster/model/task_execution"
require "toaster/state/state_transition"
require "toaster/state/system_state"
require "toaster/chef/resource_inspector"
require "toaster/model/task_parameter"

module Toaster
  class Task < MongoDBObject

    attr_accessor :uuid, :resource, :action, :parameters,
      :sourcecode, :sourcehash, :sourcefile, :sourceline
    attr_reader :resource_obj

    @@id_attributes = ["resource", "action", "sourcehash", "sourcefile", "sourceline"]

    def initialize(resource, action, sourcecode, uuid = nil)
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
    def global_executions(success=nil)
      # TODO: make caching configurable!!
      if @executions_cache.empty?
        params = {"task_id" => id()}
        @executions_cache = TaskExecution.find(params, {"task" => self})
      end
      result = []
      @executions_cache.each do |exe|
        if success.nil? || exe.success == success
          result << exe
        end
      end
      return result
    end
    def global_num_executions()
      return global_executions().size
    end
    def global_successful_executions()
      return global_executions(true)
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
    # Return an array of lists of StatePropertyChange.
    # Length of the array is the number of global executions of this task.
    # For each task execution, the array contains a list with all state
    # changes caused by this execution.
    # 
    def global_state_prop_changes(global_execs = nil)
      changes  = []
      global_execs = global_executions() if !global_execs
      global_execs.each do |exe|
        exe.state_changes.each do |sc|
          sc.task_execution = exe
        end
        #puts "execution state changes: #{exe.state_changes.inspect}"
        changes.concat(exe.state_changes)
      end
      return changes
    end
    def global_num_state_prop_changes(global_executions = nil)
      return global_state_prop_changes(global_executions).size
    end

    #
    # Return a map StatePropertyChange -> Integer .
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
      ignore_props = automation ? automation.ignore_properties.dup : []
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
      ignore_props = automation ? automation.ignore_properties.dup : []
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
      ignore_props = automation ? automation.ignore_properties.dup : []
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
      return ResourceInspector.get_config_for_potential_state_changes(self)
    end

    def guess_potential_state_changes()
      return ResourceInspector.guess_potential_state_changes(self)
    end

    def automation 
      # TODO refactor (avoid Automation.find)
      automations = Automation.find("task_ids" => { "$all" => [@uuid] })
      puts "WARN: Expected 1 automation for task '#{uuid}', got #{automations.size}" if automations.size > 1
      return automations[0] if automations && !automations.empty?
      execs = TaskExecution.find({"task_id" => self.id})
      return nil if !execs || execs.empty?
      return execs[0].automation_run.automation
    end

    def save
      @parameters.each do |p|
        if p.kind_of?(TaskParameter)
          p.save
        end
      end
      return super(@@id_attributes)
    end

    def name
      return "#{resource}::#{action}"
    end

    def parameters()
      # lazily load parameters
      if !@parameters.empty? && !@parameters[0].kind_of?(TaskParameter)
        @parameters = @parameters.collect { |p| 
          TaskParameter.find({"uuid" => p.to_s}, {"task" => self})[0]
        }
      end
      @parameters
    end

    def self.find(criteria={})
      criteria["db_type"] = "automation_task" if !criteria["db_type"]
      objs = []
      DB.instance.find(criteria).each do |hash|
        obj = Task.new(nil, nil, nil)
        objs << DB.apply_values(obj, hash)
      end
      return objs
    end

    def self.load(id_or_resource, action = nil, sourcecode = nil, sourcefile = nil, sourceline = 0)
      task = Task.new(nil, nil, nil)
      hash = {}
      if action == nil
        id = id_or_resource
        return nil if !id
        id = DB.instance.wrap_db_id(id)
        criteria = {"_id" => id, "db_type" => "automation_task"}
        hash = DB.instance.find_one(criteria)
        return nil if !hash
        task = DB.apply_values(task, hash)
      else
        resource = id_or_resource
        task = Task.new(resource, action, sourcecode)
        task.sourcefile = sourcefile
        task.sourceline = sourceline
        hash = DB.instance.get_or_insert(task.to_hash(), @@id_attributes)
      end
      DB.apply_values(task, hash)
      task.parameters = hash["parameter_ids"]
      return task
    end

    def to_hash(exclude_fields = [], additional_fields = {}, recursion_fields = [])
      exclude_fields << "parameters" if !exclude_fields.include?("parameters")
      exclude_fields << "resource_obj" if !exclude_fields.include?("resource_obj")
      additional_fields["name"] = "#{@resource} - #{@action}" if !additional_fields["name"]
      additional_fields["parameter_ids"] = @parameters.collect { |p| p.uuid } if !additional_fields["parameter_ids"]
      return super(exclude_fields, additional_fields, recursion_fields)
    end

    def hash()
      return uuid ? uuid.hash() : 0
    end

    def eql?(other)
      return other.kind_of?(Task) && !uuid.nil? && uuid == other.uuid
    end

  end
end
