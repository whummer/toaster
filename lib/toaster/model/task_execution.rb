

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/model/task"
require "toaster/model/state"
require "toaster/model/state_change"
require "toaster/model/automation_run"
require "toaster/util/timestamp"

module Toaster
  class TaskExecution < ActiveRecord::Base

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

    def self.load_all_for_automation(auto)
      return joins(:automation_run).where(
        :automation_runs => {:automation_id => auto.id})
    end

  end
end
