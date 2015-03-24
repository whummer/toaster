#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require 'active_record'
require "toaster/markup/markup_util"
require "toaster/chef/chef_util"
require "toaster/model/automation_run"
require "toaster/model/automation_attribute"
require "toaster/model/ignore_property"
require "toaster/model/additional_property"
require "toaster/state/system_state"
require "toaster/util/util"
require "toaster/db/db"
require "toaster/util/timestamp"

module Toaster
  class Automation < ActiveRecord::Base

    belongs_to :user
    has_many :tasks, :autosave => true, :dependent => :destroy
    has_many :test_suites, :autosave => true, :dependent => :destroy
    has_many :automation_attributes, :autosave => true, :dependent => :destroy
    has_many :ignore_properties, :autosave => true, :dependent => :destroy
    has_many :additional_properties, :autosave => true, :dependent => :destroy
    has_many :automation_runs, :autosave => true, :dependent => :destroy

    #attr_accessor :tasks, :attributes,
    attr_accessor  :chef_run_list, :additional_state_configs, :version

    def initialize(attr_hash)
      if !attr_hash[:uuid]
        attr_hash[:uuid] = Util.generate_short_uid()
      end
      super(attr_hash)
    end

    def get_globally_executed_tasks()
      exec_tasks = Task.
          joins(:task_executions => {:automation_run => :automation}).
          where("automation_runs.automation_id = #{self.uuid}").
          distinct()
      return exec_tasks if !exec_tasks.empty?
      return tasks
    end

    # collect the executed state transitions of
    # all tasks contained in this automation
    def global_state_transitions()
      result = Set.new
      get_globally_executed_tasks().each do |task|
        result += task.global_state_transitions
      end
      return result
    end
    def num_global_state_transitions()
      global_state_transitions().size
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

    def get_all_test_cases()
      TestCase.joins(:automation_run => :automation).where(
        "automations.id = #{self.uuid}")
    end

    def is_chef?
      "#{language}".casecmp("chef") == 0
    end

    def short_name()
      get_short_name()
    end
    def get_short_name() 
      return ChefUtil.extract_node_name(name)
    end

    def get_flat_attributes()
      KeyValuePair.get_as_hash(automation_attributes)
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

    # TODO: fix/revise
    def get_seen_attribute_values()
      map = {}
      attribute_names = self.class.get_attribute_array_names(automation_attributes,"")
      runs = automation_runs()
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
      tasks.each do |t|
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
      automation_runs().each do |r|
        run_ids << r.id
        if r.id.to_s == automation_run_id.to_s || r.uuid.to_s == automation_run_id.to_s
          return r
        end
      end
      puts "WARN: Did not find automation run '#{automation_run_id}' in automation '#{uuid}'. Existing runs: #{run_ids.inspect}"
      puts caller
      return nil
    end

    def get_num_runs()
      return automation_runs.size
    end

    def get_task(task_id, check_automation_runs=false)
      task_id = task_id.to_s
      tasks.each do |t| 
        return t if (t.id.to_s == task_id || t.uuid.to_s == task_id)
      end
      if check_automation_runs
        automation_runs().each do |r|
          r.task_executions().each do |exe|
            if exe.task && (exe.task.id.to_s == task_id || exe.task.uuid == task_id)
              return exe.task
            end
          end
        end
      end
      raise "WARN: Did not find task '#{task_id}' in automation '#{uuid}'"
    end

    def get_task_ids()
      task_ids = []
      tasks.each do |t| task_ids.push(t.uuid) end
      return task_ids
    end

    def self.find_by_cookbook_and_runlist(automation_name, run_list)
      criteria = {
        :cookbook => automation_name, 
        :recipes => run_list.to_s,
        :user => User.get_current_user
      }
      auto = find(criteria)
      puts "Automation for user=#{User.get_current_user} and name='#{automation_name}' : #{auto}"
      return auto
    end

    def self.find(criteria={})
      DB.find_activerecord(Automation, criteria)
    end

    def self.load_for_chef(name, task_list = nil, attributes = nil, chef_run_list = nil)
      params = {
        :user => User.get_current_user(),
        :name => name,
        :cookbook => name,
        :recipes => chef_run_list.to_s,
        :language => "Chef"
      }
      auto = find_by(params)
      if !auto
        auto = Automation.new(params)
      else
        auto = auto[0]
      end
      if task_list && auto.tasks.empty?
        auto.tasks.concat(task_list)
      end
      if attributes && auto.automation_attributes.empty?
        attr_array = []
        attributes.each do |k,v|
          attr_array << AutomationAttribute.new(:key => k, :value => v)
        end
        auto.automation_attributes.concat(attr_array)
      end
      return auto
    end

    # TODO move/remove?
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

  end
end
