

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/util/timestamp"
require "toaster/model/automation_run"
require "toaster/test/test_suite"
require "toaster/test/test_attribute"

include Toaster

module Toaster
  class TestCase < ActiveRecord::Base

    belongs_to :test_suite
    belongs_to :automation_run
    has_many :test_attributes, :autosave => true, :dependent => :destroy
    serialize :skip_task_uuids, JSON
    serialize :repeat_task_uuids, JSON

    def initialize(attr_hash)
      if !attr_hash[:uuid]
        attr_hash[:uuid] = Util.generate_short_uid()
      end
      if !attr_hash[:skip_task_uuids]
        attr_hash[:skip_task_uuids] = []
      end
      if !attr_hash[:repeat_task_uuids]
        attr_hash[:repeat_task_uuids] = []
      end
      super(attr_hash)
    end

    def executed?
      return !automation_run.nil? && !automation_run.end_time.nil?
    end
    def scheduled?
      return !start_time.nil?
    end
    def running_or_scheduled?
      return scheduled? && !executed?
    end

    def delete_test_result()
      # delete all task executions
      automation_run.task_executions.each do |exe|
        exe.destroy
      end
      # delete automation run
      automation_run.destroy
      # reset properties and save
      automation_run = nil
      start_time = 0
      end_time = nil
      save()
    end

    def create_chef_node_attrs()
      attrs = {
        "toaster" => {
          # set task IDs which are to be skipped during the test execution
          "skip_tasks" => skip_task_uuids.dup,
          # set task IDs which are to be repeated during the test execution
          # (for testing idempotence)
          "repeat_tasks" => repeat_task_uuids.dup,
          "user_id" => test_suite.user.id,
          "automation_uuid" => test_suite.automation.uuid
        }
      }
      return attrs
    end

    def run_attributes()
      return [] if !automation_run
      return automation_run.run_attributes.to_a.dup
    end

    def executed_task_uuids()
      result = []
      if automation_run
        automation_run.task_executions.each do |exec|
          result << exec.task.uuid
        end
      end
      return result
    end

    def repeated_tasks(only_task_names=false)
      if !automation_run
        return []
      end
      result = repeat_task_uuids.collect { |t|
        if t.kind_of?(Array)
          t.collect { |t1|
            task = automation_run.automation.get_task(t1, true)
            only_task_names ? task.name : task
          }
        else
          task = automation_run.automation.get_task(t, true)
          only_task_names ? task.name : task
        end
      }
      return result
    end

    def get_gross_duration()
      return (end_time && start_time) ? (end_time.to_i - start_time.to_i) : 0
    end

    def get_net_duration()
      r = automation_run
      time = 0
      if r
        r.task_executions.each do |exec|
          time += exec.end_time - exec.start_time
        end
      end
      return time
    end
    
    def task_executions(task_uuid=[])
      task_uuid = [task_uuid] if !task_uuid.kind_of?(Array)
      return [] if !automation_run
      automation_run.task_executions.each do |exec|
        if task_uuid.empty? || task_uuid.include?(exec.task.uuid)
          result << exec
        end
      end
    end

    def task_execution(task_uuid)
      list = task_executions(task_uuid)
      return nil if list.empty?
      if list.size != 1
        puts "WARN: Expected 1 task execution, got #{list.size}; for task uuid: #{task_uuid}"
      end
      return list[0]
    end

    def success
      return automation_run ? automation_run.success : nil
    end

    # force loading of associations from DB
    def load_associations
      hash() # loads all
    end

    def hash()
      h = 0
      h += skip_task_uuids.hash
      h += repeat_task_uuids.hash
      h += test_suite.uuid.hash if test_suite
      h += test_attributes ? test_attributes.hash : 0
      return h
    end

    def ==(obj)
      return eql?(obj)
    end

    def eql?(obj)
      return false if !obj.kind_of?(TestCase)
      return true if uuid && (uuid == obj.uuid)
      attr1 = test_attributes(false) ? test_attributes(false) : {}
      attr2 = obj.test_attributes(false) ? obj.test_attributes(false) : {}
      return skip_task_uuids == obj.skip_task_uuids &&
              repeat_task_uuids == obj.repeat_task_uuids &&
              test_suite.uuid == obj.test_suite.uuid && 
              attr1 == attr2
    end

    def self.find(criteria={})
      DB.find_activerecord(TestCase, criteria)
    end

  end
end
