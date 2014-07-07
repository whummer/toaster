

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "active_record"
require "toaster/model/automation"
require "toaster/model/task_execution"
require "toaster/model/run_attribute"
require "toaster/state/system_state"
require "toaster/util/timestamp"
require "toaster/util/util"

module Toaster
  class AutomationRun < ActiveRecord::Base

    @@current_run = nil

    belongs_to :user
    belongs_to :automation
    has_many :task_executions, nil, {:autosave => true, :dependent => :delete_all}
    has_many :run_attributes, nil, {:autosave => true, :dependent => :delete_all}

    # FIELDS: 
    #  :uuid, :machine_id, :automation, :start_time, 
    #  :end_time, :success, :error_details, :attributes

    def initialize(attr_hash)
      if !attr_hash[:uuid]
        attr_hash[:uuid] = Util.generate_short_uid()
      end
      if !attr_hash[:start_time]
        attr_hash[:start_time] = TimeStamp.now.to_i
      end
      if !attr_hash[:machine_id]
        attr_hash[:machine_id] = Util.get_machine_id()
      end
      super(attr_hash)
    end
  
    # used in the context of a currently active run
    def self.get_current
      return @@current_run
    end
    # used in the context of a currently active run
    def self.set_current(run)
      run.save
      @@current_run = run
    end

    def get_flat_attributes()
      KeyValuePair.get_as_hash(run_attributes)
    end

    def get_executed_tasks()
      result = []
      task_executions.each do |exec|
        result << exec.task
      end
      return result
    end

    def get_num_task_executions()
      return task_executions.size
    end

    def get_task_execution(task)
      task_executions().each do |e|
        if e.task.uuid == task.uuid
          return e
        end
      end
    end

    def task_execution_index(task_exec)
      task_executions().each_with_index do |e,idx|
        if e.uuid == task_exec.uuid
          return idx
        end
      end
      return nil
    end

    def duration
      return nil if !end_time || !start_time
      return end_time - start_time
    end

    def self.load(id, automation = nil)
      id = DB.instance.wrap_db_id(id)
      preset_fields = {}
      preset_fields["automation"] = automation if automation
      runs = find({"_id" => id}, preset_fields)
      return nil if !runs || runs.empty?
      return runs[0]
    end

    def self.find(criteria={})
      DB.find_activerecord(AutomationRun, criteria)
    end

  end
end
