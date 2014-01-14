

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/db/mongodb_object"
require "toaster/model/automation"
require "toaster/state/system_state"
require "toaster/util/timestamp"
require "toaster/util/util"
require "toaster/model/task_execution"

module Toaster
  class AutomationRun < MongoDBObject

    attr_accessor :uuid, :machine_id, :automation, :start_time, 
      :end_time, :success, :error_details, :attributes

    @@current_run = nil

    def initialize(automation, machine_id=nil, attributes = {}, uuid = nil)
      @db_type = "automation_run"
      @uuid = uuid ? uuid : Util.generate_short_uid()
      @machine_id = machine_id ? machine_id : Util.get_machine_id()
      @attributes = attributes
      @start_time = TimeStamp.now.to_i
      @end_time = nil
      @automation = automation
      @success = true
      @error_details = false
      #@task_executions_cache = nil
      @flat_attributes_cache = nil
    end

    def self.get_current
      return @@current_run
    end
    def self.set_current(run)
      run = run.save
      @@current_run = run
    end

    def get_flat_attributes()
      if @flat_attributes_cache
        return @flat_attributes_cache
      end
      @flat_attributes_cache = SystemState.get_flat_attributes(@attributes)
      return @flat_attributes_cache
    end

    def get_executed_tasks(do_cache=false, task_executions=nil)
      result = []
      task_executions = get_task_executions() if !task_executions
      task_executions.each do |exec|
        if exec.task
          result << exec.task
        else
          puts "WARN: No task associated with task execution '#{exec}' of automation run '#{self}'"
        end
      end
      return result
    end

    def get_num_task_executions()
      return get_task_executions(false).size
    end

    def get_task_executions(load_cascading = true, tasks=nil)
      props = {"ruby_type"=>"list_of_task_executions", "automation_run_id" => uuid}
      return Cache.by_obj_props(props) if Cache.by_obj_props(props)
      #return @task_executions_cache if @task_executions_cache

      preset_fields = {"automation_run" => self}
      preset_fields["automation"] = automation if automation
      preset_fields["task_id"] = nil if !load_cascading
      criteria = {"automation_run_id" => id}
      exec = []
      exec = TaskExecution.find(criteria, preset_fields)
      exec.sort! { |x,y| x.start_time <=> y.start_time }
      #@task_executions_cache = exec
      Cache.set(exec, props)
      return exec
    end

    def get_task_execution(task)
      get_task_executions().each do |e|
        if e.task.uuid == task.uuid
          return e
        end
      end
    end

    def task_execution_index(task_exec)
      get_task_executions().each_with_index do |e,idx|
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

    def self.find(criteria={}, preset_fields={})

      criteria["db_type"] = "automation_run" if !criteria["db_type"]
      runs = []
      begin
        found_runs = DB.instance.find(criteria)
        found_runs.each do |run_hash|
          auto = preset_fields.include?("automation") ? preset_fields["automation"] :
                Automation.load(run_hash["automation_id"])
          run = AutomationRun.new(auto, nil)
          runs << DB.apply_values(run, run_hash)
        end
      rescue => ex
        puts "Cannot query criteria in DB: #{criteria}"
        raise ex
      end
      return runs
    end

    def save
      return super(["uuid"])
    end

    def delete()
      get_task_executions.each do |exe|
        exe.delete
      end
      super
    end

    def to_hash(exclude_fields = [], additional_fields = {}, recursion_fields = [])
      return super(
          ["automation"], 
          {
            "automation_id" => automation.nil? ? nil : automation.id,
            "automation_name" => automation.nil? ? nil : automation.name
          })
    end
  end
end
