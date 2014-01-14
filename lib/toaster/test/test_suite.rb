

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/util/util"
require "toaster/test/test_coverage"
require "toaster/db/mongodb_object"
require "toaster/test/test_case"
require "toaster/db/db"
require "toaster/model/automation"
require "toaster/state/convergence"

include Toaster

module Toaster
  class TestSuite < MongoDBObject

    attr_accessor :uuid, :automation, :test_cases, :recipes, 
      :lxc_prototype, :parameter_test_values, :coverage_goal, :name

    def initialize(automation, recipes = [], uuid = nil, prototype="default")
      @db_type = "test_suite"
      @uuid = uuid ? uuid : Util.generate_short_uid()
      @automation = automation
      @recipes = recipes.kind_of?(Array) ? recipes : [recipes]
      @coverage_goal = TestCoverageGoal.new
      @lxc_prototype = prototype
      # mapping <parameterName> -> [<parameterValue> ...]
      @parameter_test_values = {}
      @test_cases = []
      @name = @uuid
    end

    # Returns the total gross duration of all test cases in this suite.
    # Gross duration includes times for 
    # initialization + actual test execution + cleanup.
    def get_gross_duration()
      durations = @test_cases.collect{ |c| c.get_gross_duration() }
      return durations.reduce(:+)
    end

    # Returns the total net duration of all test cases in this suite.
    # Net duration includes times for the actual test execution 
    # (not including initialization or cleanup).
    def get_net_duration()
      durations = @test_cases.collect{ |c| 
        c.get_net_duration()
      }
      return durations.reduce(:+)
    end

    def automation_name()
      return automation ? automation.name : "n/a"
    end
    def automation_version()
      return automation ? automation.version : "n/a"
    end

    def last_test_time()
      l = last_test
      return l ? l.start_time : "n/a"
    end

    def contains_equal_test?(test_case)
      @test_cases.each do |test|
        if test.eql?(test_case)
          return true
        end
      end
      return false
    end

    def self.get_uuids() 
      return find().collect { |suite| suite.uuid }
    end

    def self.find(criteria={}, load_associations = true)
      criteria["db_type"] = "test_suite" if !criteria["db_type"]
      suites = []
      DB.instance.find(criteria).each do |hash|
        s = TestSuite.new(nil)
        s.automation = Automation.load(hash["automation_id"]) if hash["automation_id"] && load_associations
        s.coverage_goal = TestCoverageGoal.from_hash(hash["coverage_goal_hash"]) if hash["coverage_goal_hash"]
        s = DB.apply_values(s, hash)
        s.load_test_cases_from_db() if load_associations
        suites << s
      end
      return suites
    end

    def self.load(id, load_associations = true)
      id = DB.instance.wrap_db_id(id)
      criteria = {"_id" => id}
      objects = find(criteria, load_associations)
      return nil if objects.empty?
      o = objects[0]
      o.load_test_cases_from_db() if load_associations
      return o
    end

    def query_unfinished_tests 
      return TestCase.find(
        {"automation_run_id" => nil, "test_suite_id" => id}, 
        {"test_suite" => self}
      )
    end
    def test_cases_finished
      return @test_cases.select { |test| test.executed? }
    end
    def test_cases_sorted
      return @test_cases.sort { |x,y|
        !x.start_time ? -1 : 
        !y.start_time ? 1 :
        x.start_time <=> y.start_time 
      }
    end
    def test_cases_failed
      return @test_cases.select { |test| test.success == false }
    end
    def test_cases_succeeded
      return @test_cases.select { |test| test.success == true }
    end
    def first_test
      cases_copy = test_cases_sorted()
      return cases_copy.empty? ? nil : cases_copy[0]
    end
    def last_test
      cases_copy = test_cases_sorted()
      return cases_copy.empty? ? nil : cases_copy[-1]
    end

    def add_test_results(res, prefix="", preset_values={})
      res.add_entry("#{prefix}numTests", test_cases.size)
      res.add_entry("#{prefix}numTestsFinished", test_cases_finished.size)
      res.add_entry("#{prefix}numTestsOpen", test_cases.size - test_cases_finished.size)
      res.add_entry("#{prefix}numTestsFailed", test_cases_failed.size)
      res.add_entry("#{prefix}numTestsSuccess", test_cases_succeeded.size)
      res.add_entry("#{prefix}percTestsFailed", test_cases_failed.size.to_f / test_cases.size.to_f)
      res.add_entry("#{prefix}percTestsSuccess", test_cases_succeeded.size.to_f / test_cases.size.to_f)
      #res.add_entry("#{prefix}numConvProps", preset_values["numConvProps"] ? preset_values["numConvProps"] :
      #    Convergence.convergence_for_automation(@automation).size)
      res.add_entry("#{prefix}numAutoTasks", @automation.tasks.size)
      res.add_entry("#{prefix}durationGross", get_gross_duration())
      res.add_entry("#{prefix}durationNet", get_net_duration())
      test_cases_sorted.each_with_index do |test,idx|
        res.add_entry("#{prefix}t#{idx}startTime", test.start_time)
        res.add_entry("#{prefix}t#{idx}durationGross", test.get_gross_duration)
        res.add_entry("#{prefix}t#{idx}durationNet", test.get_net_duration)
        res.add_entry("#{prefix}t#{idx}success", test.success ? 1 : 0)
      end
    end

    def to_hash(exclude_fields = [], additional_fields = {}, recursion_fields = [])
      exclude_fields << "automation" if !exclude_fields.include?("automation")
      exclude_fields << "test_cases" if !exclude_fields.include?("test_cases")
      exclude_fields << "coverage_goal" if !exclude_fields.include?("coverage_goal")
      additional_fields["automation_id"] = @automation.nil? ? nil : @automation.id
      additional_fields["test_case_ids"] = test_cases.collect { |c| c.uuid } if test_cases
      additional_fields["coverage_goal_hash"] = coverage_goal.to_hash if coverage_goal
      return super(exclude_fields, additional_fields, recursion_fields)
    end

    def save()
      @test_cases.each do |test|
        if !test.id
          test.save
        end
      end
      return super(["uuid"])
    end

    def load_test_cases_from_db()
      criteria = { "test_suite_id" => id }
      @test_cases = TestCase.find(criteria, {"test_suite" => self})
    end

    def delete()
      if !id || id.to_s.strip == ""
        puts "WARN: Unable to delete DB object with empty id: #{self}"
        return false
      end
      @test_cases.each do |t|
        t.delete()
      end
      super
      return true
    end

  end
end
