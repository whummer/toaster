

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/db/mongodb_object"
require "toaster/model/automation_run"
require "toaster/markup/markup_util"
require "toaster/chef/chef_util"
require "toaster/state/system_state"
require "toaster/util/util"
require "toaster/model/automation_run"
require "toaster/model/task"

module Toaster
  class Automation < MongoDBObject

    attr_accessor :uuid, :name, :tasks, :attributes, :chef_run_list, 
      :ignore_properties, :additional_state_configs, :version

    def initialize(name, tasks = [], attributes = {}, uuid = nil)
      @db_type = "automation"
      @name = name
      @version = "latest"
      @chef_run_list = []
      @attributes = attributes
      @ignore_properties = []
      @additional_state_configs = {}
      @uuid = uuid ? uuid : Util.generate_short_uid()
      @tasks = tasks
    end

    def self.get_attribute_array_names(current, array_name="node", name_so_far=array_name, list_so_far=[])
      return list_so_far if current.nil?
      if !current.kind_of?(Hash)
        list_so_far << name_so_far
        return list_so_far
      end
      current.each do |name,value|
        name = "#{name_so_far}['#{name}']"
        get_attribute_array_names(value, array_name, name, list_so_far)
      end
      return list_so_far
    end

    def get_globally_executed_tasks()
      result = []
      TimeStamp.add(nil, "get_task_execs")
      task_executions = get_task_execs_by_run()
      TimeStamp.add_and_print("load executed tasks", nil, "get_task_execs") { |duration| duration > 10 }
      runs = task_executions.keys
      runs.each do |run|
        #tasks = run.get_executed_tasks()
        tasks = task_executions[run].collect { |task_run| task_run.task }
        tasks.each do |task|
          if task && task.id
            if !MongoDBObject.list_include?(result, task)
              result << task
            end
          end
        end
      end
      return result
    end

    # 
    # return a map AutomationRun -> (list of TaskExecution)
    #
    def get_task_execs_by_run()
      result = {}
      task_execs = TaskExecution.load_all_for_automation(self)
      task_execs.each do |exe|
        result[exe.automation_run] = [] if !result[exe.automation_run]
        result[exe.automation_run] << exe
      end
      return result
    end

    def short_name()
      get_short_name()
    end
    def get_short_name() 
      return ChefUtil.extract_node_name(name)
    end

    def get_flat_attributes()
      return SystemState.get_flat_attributes(@attributes)
    end

    def get_default_value(parameter_name)
      a = get_attribute(parameter_name)
      return nil if !a
      return a[1]
    end

    def get_attribute(attr_name)
      attribs = get_flat_attributes()
      val = attribs[attr_name]
      return [attr_name,val] if val
      return nil
    end

    def get_seen_attribute_values()
      map = {}
      attribute_names = self.class.get_attribute_array_names(@attributes,"")
      runs = get_runs()
      runs.each do |run|
        attribute_names.each do |param_array_path|
          name = MarkupUtil.convert_array_to_dot_notation(param_array_path)
          map[name] = [] if !map[name]
          val = nil
          eval("val = run.run_attributes#{param_array_path}")
          map[name] << val
        end
      end
      map.each do |key,array|
        array.uniq!
      end
      return map
    end

    def all_affected_property_names()
      result = Set.new
      @tasks.each do |t|
        t.global_state_transitions.each do |st|
          st.pre_state.each do |key,val|
            result << key
          end
        end
      end
      result = result.to_a.sort
      return result
    end

    def get_run(automation_run_id)
      run_ids = []
      get_runs().each do |r|
        run_ids << r.id
        if r.id.to_s == automation_run_id.to_s || r.uuid.to_s == automation_run_id.to_s
          return r
        end
      end
      puts "WARN: Did not find automation run '#{automation_run_id}' in automation '#{uuid}'. Existing runs: #{run_ids.inspect}"
      puts caller
      return nil
    end

    def get_runs()
      # TODO: This method is a performance killer if the database is 
      # filled with many objects..! Maybe add some sort of short-time caching, 
      # e.g., on a per-request basis, otherwise we end up fetching all 
      # automation runs from the DB over and over again!

      # load result from cache
      props = { "ruby_type" => "automation_runs_list", "automation_uuid" => uuid}
      return Cache.by_obj_props(props) if Cache.by_obj_props(props)

      TimeStamp.add(nil, "get_runs")
      runs = Toaster::AutomationRun.find(
        {"automation_id" => id}, {"automation" => self})
      TimeStamp.add_and_print("load automation runs", nil, "get_runs") { |duration| duration > 10 }

      # put result to cache
      Cache.set(runs, props)

      return runs
    end

    def get_num_runs()
      return get_runs().size
    end

    def get_task(task_id, check_automation_runs=false)
      task_id = task_id.to_s
      @tasks.each do |t| 
        return t if t.id.to_s == task_id || t.uuid.to_s == task_id
      end
      if check_automation_runs
        get_runs().each do |r|
          r.get_task_executions().each do |exe|
            if exe.task && exe.task.uuid.to_s == task_id || exe.task.uuid.to_s == task_id
              return exe.task
            end
          end
        end
      end
      raise "WARN: Did not find task '#{task_id}' in automation '#{uuid}'"
    end

    def get_task_ids()
      task_ids = []
      @tasks.each do |t| task_ids.push(t.uuid) end
      return task_ids
    end

    def to_hash(exclude_fields = [], additional_fields = {}, recursion_fields = [])
      task_ids = get_task_ids()
      return super(["tasks"], {"task_ids" => task_ids})
    end

    def save()
      return super(["uuid"])
    end

    def delete()
      tasks.each do |task|
        task.delete()
      end
      super
    end

    def self.find_by_name_and_runlist(automation_name, actual_run_list)
      criteria = { "name" => automation_name, "chef_run_list" => actual_run_list }
      automations = find(criteria)
      return !automations.empty? ? nil : automations[0]
    end

    def self.find(criteria={})
      criteria["db_type"] = "automation" if !criteria["db_type"]
      autos = []
      DB.instance.find(criteria).each do |auto_hash|
        #puts "auto hash: #{auto_hash}"
        task_ids = auto_hash["task_ids"]
        task_list = nil
        task_list = Task.find({"uuid" => {"$in" => task_ids}}) if task_ids
        auto = Automation.new(nil, task_list)
        auto.tasks = task_list
        autos << DB.apply_values(auto, auto_hash)
      end
      return autos
    end

    def self.load(name_or_id, task_list = nil, attributes = nil, chef_run_list = nil)
      #puts "Loading automation for #{name_or_id} - #{task_list} - #{attributes}"
      if task_list.nil?
        id = name_or_id
        return nil if !id
        id = DB.instance.wrap_db_id(id)
        criteria = {"_id" => id, "db_type" => "automation"}
        hash = DB.instance.find_one(criteria)
        return nil if !hash
        auto = Automation.new(nil)
        task_ids = hash["task_ids"]
        auto.tasks = Task.find({"uuid" => {"$in" => task_ids}}) if task_ids
        return DB.apply_values(auto, hash)
      else
        name = name_or_id
        auto = Automation.new(name_or_id, task_list, attributes)
        auto.chef_run_list = chef_run_list
        #puts "Trying to find automation for hash: #{auto.to_hash()}"
        hash = DB.instance.get_or_insert(auto.to_hash(), ["name", "chef_run_list", "attributes"])
        return DB.apply_values(auto, hash)
      end
    end

  end
end
