

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/util/util"
require "toaster/test/test_coverage"
require "toaster/test/test_case"
require "toaster/model/automation"
require "toaster/model/user"
require "toaster/state/convergence"
require "toaster/db/db"

include Toaster

module Toaster
  class TestSuite < ActiveRecord::Base

    belongs_to :automation
    belongs_to :user
    belongs_to :test_coverage_goal
    has_many :test_cases, :autosave => true, :dependent => :destroy
    serialize :parameter_test_values, JSON

    def initialize(attr_hash)
      if !attr_hash[:uuid]
        attr_hash[:uuid] = Util.generate_short_uid()
      end
      if !attr_hash[:test_coverage_goal]
        attr_hash[:test_coverage_goal] = TestCoverageGoal.new
      end
      super(attr_hash)
    end

    # Returns the total gross duration of all test cases in this suite.
    # Gross duration includes times for 
    # initialization + actual test execution + cleanup.
    def get_gross_duration()
      durations = test_cases.collect{ |c| c.get_gross_duration() }
      return durations.reduce(:+)
    end

    # Returns the total net duration of all test cases in this suite.
    # Net duration includes times for the actual test execution 
    # (not including initialization or cleanup).
    def get_net_duration()
      durations = test_cases.collect{ |c| 
        c.get_net_duration()
      }
      return durations.reduce(:+)
    end

    def coverage_goal
      test_coverage_goal
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
      test_cases.each do |test|
        if test.eql?(test_case)
          return true
        end
      end
      return false
    end

    def self.get_uuids() 
      return find().collect { |suite| suite.uuid }
    end

    def test_cases_finished
      return test_cases.select { |test| test.executed? }
    end
    def test_cases_sorted(cases=test_cases)
      return cases.sort { |x,y|
        !x.start_time ? 1 : 
        !y.start_time ? -1 :
        x.start_time <=> y.start_time 
      }
    end
    def test_cases_failed
      return test_cases.select { |test| test.success == false }
    end
    def test_cases_succeeded
      return test_cases.select { |test| test.success == true }
    end
    def executed_test_cases
      test_cases.select { 
              |c| c.start_time &&
              !("#{c.start_time}".empty?) }
    end
    def first_test
      cases_copy = test_cases_sorted(executed_test_cases)
      return cases_copy.empty? ? nil : cases_copy[0]
    end
    def last_test
      cases_copy = test_cases_sorted(executed_test_cases)
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

    def self.load(id, load_associations = true)
      return nil if !id
      find(id)
    end
    def self.find(criteria={})
      DB.find_activerecord(TestSuite, criteria)
    end

    def query_unfinished_tests 
      return TestCase.find(
        :automation_run => nil,
        :test_suite_id => id
      )
    end

  end
end
