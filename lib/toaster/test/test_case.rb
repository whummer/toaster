

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/db/mongodb_object"
require "toaster/util/timestamp"
require "toaster/model/automation_run"
require "toaster/test/test_suite"

include Toaster

module Toaster
  class TestCase < MongoDBObject

    attr_accessor :uuid, :test_suite, :skip_task_uuids, 
      :repeat_task_uuids, :start_time, :end_time, :automation_run, :executing_host

    def initialize(test_suite, uuid = nil)
      now = TimeStamp.now.to_i
      @db_type = "test_case"
      @uuid = uuid.nil? ? Util.generate_short_uid() : uuid
      @test_suite = test_suite
      @skip_task_uuids = []
      @repeat_task_uuids = []
      @start_time = now
      @end_time = nil
      @executing_host = nil
      @automation_run = nil
      @task_execution_cache = {}
      @attributes = nil
    end

    def executed?()
      return !@automation_run.nil? && !@automation_run.end_time.nil?
    end

    def delete_test_result()
      # delete all task executions
      @automation_run.get_task_executions.each do |exe|
        exe.delete
      end
      # delete automation run
      @automation_run.delete
      # reset properties and save
      @automation_run = nil
      @start_time = 0
      @end_time = nil
      save()
    end

    def create_chef_node_attrs()
      attrs = {
        "toaster_testing" => {
          # set task IDs which are to be skipped during the test execution
          "skip_tasks" => @skip_task_uuids.dup,
          # set task IDs which are to be repeated during the test execution
          # (for testing idempotence)
          "repeat_tasks" => @repeat_task_uuids.dup
        }
      }
      return attrs
    end

    def attributes(load_from_automation_run=true)
      result = @attributes ? @attributes : {}
      if result.empty? && load_from_automation_run && @automation_run
        result = @automation_run.attributes
        result = result ? result : {}
      end
      return result
    end

    def executed_task_uuids()
      result = []
      @automation_run.get_task_executions().each do |exec|
        result << exec.task.uuid
      end
      return result
    end

    def repeated_tasks(only_task_names=false)
      if !@automation_run
        return []
      end
      result = repeat_task_uuids.collect { |t|
        if t.kind_of?(Array)
          t.collect { |t1|
            task = @automation_run.automation.get_task(t1, true)
            only_task_names ? task.name : task
          }
        else
          task = @automation_run.automation.get_task(t, true)
          only_task_names ? task.name : task
        end
      }
      return result
    end

    def get_gross_duration()
      return (end_time && start_time) ? (end_time - start_time) : 0
    end

    def get_net_duration()
      r = @automation_run
      time = 0
      if r
        r.get_task_executions().each do |exec|
          time += exec.end_time - exec.start_time
        end
      end
      return time
    end

    def task_executions(task_uuid=[], do_cache=false)
      task_uuid = [task_uuid] if !task_uuid.kind_of?(Array)
      return @task_execution_cache[task_uuid] if do_cache && @task_execution_cache[task_uuid]
      result = []
      @automation_run.get_task_executions(true).each do |exec|
        if task_uuid.empty? || task_uuid.include?(exec.task.uuid)
          result << exec
        end
      end
      @task_execution_cache[task_uuid] = result if do_cache
      return result
    end

    def task_execution(task_uuid, do_cache=false)
      list = task_executions(task_uuid, do_cache)
      return nil if list.empty?
      if list.size > 1
        puts "WARN: Expected 1 task execution, got #{list.size}; for task uuid: #{task_uuid}"
      end
      return list[0]
    end

    def success
      return @automation_run ? @automation_run.success : nil
    end

    def self.find(criteria={}, preset_fields = {})
      criteria["db_type"] = "test_case" if !criteria["db_type"]
      cases = []
      parent_test_suite = preset_fields["test_suite"] ? preset_fields["test_suite"] : nil
      DB.instance.find(criteria).each do |hash|
        c = TestCase.new(nil)
        parent_test_suite = TestSuite.load(hash["test_suite_id"]) if hash["test_suite_id"] && !parent_test_suite
        c.test_suite = parent_test_suite
        if hash["automation_run_id"]
          if c.test_suite.automation
            begin
              c.automation_run = c.test_suite.automation.get_run(hash["automation_run_id"])
            rescue Object => ex
              puts "WARN: Unable to find automation run: #{ex}"
            end
          end
          if !c.automation_run
            c.automation_run = AutomationRun.load(hash["automation_run_id"])
          end
        end
        #puts "loaded automation run for ID #{hash["automation_run_id"]}: #{c.automation_run}"
        cases << DB.apply_values(c, hash)
      end
      return cases
    end

    def self.load(id, preset_fields = {})
      id = DB.instance.wrap_db_id(id)
      criteria = {"_id" => id}
      cases = find(criteria, preset_fields)
      return nil if cases.empty?
      return cases[0]
    end

    def save()
      if !@test_suite.nil? && !@test_suite.id
        @test_suite = @test_suite.save()
      end
      return super(["uuid"])
    end

    def hash()
      h = 0
      h += @skip_task_uuids.hash
      h += @repeat_task_uuids.hash
      h += @test_suite.uuid.hash
      h += @attributes ? @attributes.hash : 0
      return h
    end

    def eql?(obj)
      return false if !obj.kind_of?(TestCase)
      return true if uuid && (uuid == obj.uuid)
      #puts "Comparing test cases #{uuid} - #{obj.uuid}"
      #puts "#{@skip_task_uuids} =?= #{obj.skip_task_uuids} : #{@skip_task_uuids == obj.skip_task_uuids}"
      #puts "#{@repeat_task_uuids} =?= #{obj.repeat_task_uuids} : #{@repeat_task_uuids == obj.repeat_task_uuids}"
      #puts "#{@test_suite.uuid} =?= #{obj.test_suite.uuid} : #{@test_suite.uuid == obj.test_suite.uuid}"
      #puts "#{attributes} =?= #{obj.attributes} : #{(attributes ? attributes : {}) == (obj.attributes ? obj.attributes : {})}"
      attr1 = attributes(false) ? attributes(false) : {}
      attr2 = obj.attributes(false) ? obj.attributes(false) : {}
      return @skip_task_uuids == obj.skip_task_uuids &&
              @repeat_task_uuids == obj.repeat_task_uuids &&
              @test_suite.uuid == obj.test_suite.uuid &&
              attr1 == attr2
    end

    def to_hash(exclude_fields = [], additional_fields = {}, recursion_fields = [])
      exclude_fields << "test_suite" if !exclude_fields.include?("test_suite")
      exclude_fields << "automation_run" if !exclude_fields.include?("automation_run")
      additional_fields["test_suite_id"] = test_suite.nil? ? nil : test_suite.id
      additional_fields["automation_run_id"] = automation_run.nil? ? nil : automation_run.id
      return super(exclude_fields, additional_fields, recursion_fields)
    end

    def delete()
      if !id || id.to_s.strip == ""
        puts "WARN: Unable to delete DB object with empty id: #{self}"
        return false
      end
      delete_test_result()
      super
    end

  end
end
