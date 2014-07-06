

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "active_record"
require "toaster/model/task"
require "toaster/model/state"
require "toaster/model/state_change"
require "toaster/model/automation_run"
require "toaster/util/timestamp"

module Toaster
  class TaskExecution < ActiveRecord::Base

#    attr_accessor :uuid, :task, :state_before, :state_after, 
#      :state_changes, :automation_run, :success, :error_details,
#      :start_time, :end_time, :script_output, :sourcecode

    belongs_to :task
    belongs_to :automation_run
    has_many :state_changes
    serialize :state_before, JSON
    serialize :state_after, JSON

    def initialize(attr_hash)
      if !attr_hash[:uuid]
        attr_hash[:uuid] = Util.generate_short_uid()
      end
      if !attr_hash[:start_time]
        attr_hash[:start_time] = TimeStamp.now.to_i
      end
      super(attr_hash)
    end
  
#    def initialize1(task, state_before, state_after, state_changes, uuid = nil, start_time=nil)
#      @task = task
#      @start_time = start_time ? start_time : TimeStamp.now.to_i
#      @end_time = nil
#      @uuid = uuid ? uuid : Util.generate_short_uid()
#      @state_before = state_before
#      @state_after = state_after
#      @state_changes = []
#      @success = true
#      @error_details = nil
#      @db_type = "task_execution"
#      @automation_run = nil
#      @script_output = nil
#      @sourcecode = nil
#    end

    #
    # Return a map {param_name => value} of parameter values that 
    # were used for this task execution.
    #
    def get_used_parameters()
      result = {}
      run_attributes = automation_run.get_flat_attributes()
      task.task_parameters.each do |p|
        if p
          value = run_attributes[p.key]
          result[p.key] = value
        end
      end
      return result
    end

    def relevant_state_changes()
      result = state_changes.to_a.dup
      ignore_props = SystemState.read_ignore_properties()
      # remove ignored properties from state changes
      SystemState.remove_ignore_props!(result, ignore_props)
      return result
    end

    def reduce_and_set_state_after(state)
      self.state_after = state
      # limit the number of state properties which are 
      # saved for the pre-state and the post-state.
      states_new = SystemState.reduce_state_size(state_before, state_after)
      #puts "states before/after #{self}: #{state_after} #{states_new[1]}"
      self.state_before = states_new[0]
      self.state_after = states_new[1]
    end

    def self.find(criteria={})
      DB.find_activerecord(TaskExecution, criteria)
    end

#    def self.load(id, preset_fields={})
#      return nil if !id || id.to_s.strip == ""
#      id = DB.instance.wrap_db_id(id)
#      objs = find({"_id" => id}, preset_fields)
#      return nil if !objs || objs.empty?
#      return objs[0]
#    end

    # TODO: refactor/remove...?
#    def self.find(criteria={}, preset_fields={})
#      criteria["db_type"] = "task_execution" if !criteria["db_type"]
#      
#      # retrieve result from cache
#      cache_key = criteria.dup
#      cache_key.delete("db_type")
#      cache_key["ruby_type"] = "task_executions_list"
#      return Cache.by_obj_props(cache_key) if Cache.by_obj_props(cache_key)
#
#      objs = []
#      #TimeStamp.add(nil, "get_task_execs1")
#      execs = DB.instance.find(criteria)
#      #TimeStamp.add_and_print("find task executions", nil, "get_task_execs1")
#      #TimeStamp.add(nil, "get_auto_runs")
#      preset_fields["auto_runs"] = {} if !preset_fields["auto_runs"]
#      execs.each do |hash|
#        obj = nil
#        obj = TaskExecution.new(nil, nil, nil, nil, nil, hash["start_time"])
#        if preset_fields["automation_run"]
#          obj.automation_run = preset_fields["automation_run"]
#        elsif hash["automation_run_id"]
#          if preset_fields["auto_runs"][hash["automation_run_id"]]
#            obj.automation_run = preset_fields["auto_runs"][hash["automation_run_id"]]
#          elsif preset_fields["automation"]
#            auto = preset_fields["automation"]
#            begin
#              obj.automation_run = auto.get_run(hash["automation_run_id"])
#            rescue => ex
#              # swallow
#              puts "WARN: #{ex} - #{ex.backtrace}"
#            end
#            if !obj.automation_run
#              obj.automation_run = AutomationRun.load(hash["automation_run_id"], preset_fields["automation"])
#            end
#          else
#            obj.automation_run = AutomationRun.load(hash["automation_run_id"])
#          end
#          preset_fields["auto_runs"][hash["automation_run_id"]] = obj.automation_run
#        end
#
#        if preset_fields["task"]
#          obj.task = preset_fields["task"]
#        elsif hash["task_id"]
#          if obj.automation_run.automation
#            begin 
#              obj.task = obj.automation_run.automation.get_task(hash["task_id"], false)
#            rescue => ex
#              # swallow
#              #puts "WARN: #{ex} - #{ex.backtrace}"
#            end
#          end
#          if !obj.task
#            obj.task = Task.load(hash["task_id"])
#          end
#        end
#
#        obj = DB.apply_values(obj, hash)
#        if hash["state_changes"]
#          obj.state_changes = StateChange.from_hash_array(hash["state_changes"])
#        end
#        
#        objs << obj
#      end
#      #TimeStamp.add_and_print("load automation runs of all #{execs.size} task executions", nil, "get_auto_runs")
#      
#      # put result to cache
#      Cache.set(objs, cache_key)
#
#      return objs
#    end

    def self.load_all_for_automation(auto)
      return joins(:automation_run).where(:automation_run => {:automation_id => auto.id})
    end

#    def self.load_all_for_automation(auto)
#      TimeStamp.add(nil, "get_auto_runs")
#      # TODO: refactor: load only automation run IDs from DB (?)
#      auto_runs = auto.automation_runs().collect { |r| r.id }
#      TimeStamp.add_and_print("get auto runs", nil, "get_auto_runs") { |duration| duration > 10 }
#      auto_runs = auto_runs.uniq
#      task_to_execs = {}
#
#      execs = find(
#          {"automation_run_id" => {"$in" => auto_runs}}, 
#          {"automation" => auto}
#      )
#
#      execs.each do |exe|
#        if exe.task
#          task_to_execs[exe.task] = [] if !task_to_execs[exe.task]
#          task_to_execs[exe.task] << exe
#        end
#      end
#      # "notify" task about list of executions
#      task_to_execs.each do |task,execs|
#        task.set_executions(execs)
#      end
#      return execs
#    end
#    def save
#      return super(["uuid"])
#    end
#    def to_hash(exclude_fields = [], additional_fields = {}, recursion_fields = [])
#      return super(
#          ["task", "automation_run"],
#          # TODO: change task.id to task.uuid !?
#          {"task_id" => task.id, "automation_run_id" => automation_run.nil? ? nil : automation_run.id},
#          ["state_changes"])
#    end

  end
end
