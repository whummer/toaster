####################################################
# (c) Waldemar Hummer (hummer@infosys.tuwien.ac.at)
####################################################

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/test/test_case"
require "toaster/test/test_generator"
require "toaster/api"

include Toaster

module Toaster
  class TestOrchestrator

    attr_accessor :uuid, :test_suite, :skip_task_uuids,
    :repeat_task_uuids, :start_time, :end_time, :automation_run
    def initialize(config = {})
      @hosts = []
      @host_proxies = {}
      @round_robin_counter = -1
    end

    def add_host(host)
      @hosts << host
    end

    def select_host()
      raise "No hosts have been defined yet." if @hosts.empty?
      @round_robin_counter = @round_robin_counter >= @hosts.size - 1 ? 0 : @round_robin_counter + 1
      host = @hosts[@round_robin_counter]
      client = get_proxy(host)
      return client
    end

    def all_hosts()
      result = []
      @hosts.each do |host|
        result << get_proxy(host)
      end
      return result
    end

    def update_all_services()
      all_hosts.each do |h|
        t = Thread.start {
          h.update_code()
        }
      end
      sleep 9
    end

    def exec_on_all_hosts(command, output=true, parallel=true)
      out_total = ""
      mutex = Mutex.new
      block = lambda do |host|
        p = get_proxy(host)
        out_tmp = ""
        out_tmp += "INFO: Executing command on #{host}: #{command}\n"
        out = p.exec(command)
        out_tmp += "#{out}\n"
        mutex.synchronize do
          out_total += "#{out_tmp}\n"
        end
        if output
          puts out
        end
      end
      if parallel
        Util.exec_in_parallel(@hosts, &block)
      else
        @hosts.each &block
      end
      return out_total
    end

    def generate_tests(test_suite_uuid, coverage_goal)
      suite = TestSuite.find({"uuid" => test_suite_uuid})[0]
      suite.coverage_goal = coverage_goal
      generate_tests_for_suite(suite)
    end

    def generate_tests_for_suite(test_suite)
      gen = TestGenerator.new(test_suite)
      puts "INFO: Starting to generate tests..."
      tests = gen.gen_all_tests()
      puts "INFO: Generated #{tests.size} test cases for test suite #{test_suite.uuid} (#{test_suite.test_cases.size} test cases so far)."
      tests.each do |test|
        if !test_suite.contains_equal_test?(test)
          test_suite.test_cases << test
        end
      end
      puts "INFO: Test suite #{test_suite.uuid} now contains #{test_suite.test_cases.size} test cases."
      test_suite.save
    end

    def distribute_test_cases(tests_to_run)
      tests = tests_to_run
      tests_orig = tests_to_run.dup
      puts "INFO: Distributing #{tests.size} generated tests to #{@hosts.size} hosts"
      tests_by_host = {}
      while !tests.empty?
        test = tests.shift
        host = select_host()
        tests_by_host[host] = [] if !tests_by_host[host]
        tests_by_host[host] << test.uuid
        test.executing_host = host.host
      end
      tests_orig.each do |t|
        # save test case to store "t.executing_host" to DB
        t.save
      end
      tests_by_host.each do |host,test_case_list|
        puts "INFO: Sending test case list #{test_case_list} to host #{host}"
        blocking = false
        output = host.runtest(test_case_list.join(","), blocking)
      end
    end

    def distribute_tests(test_suite)
      if !test_suite.kind_of?(TestSuite)
        test_suite = TestSuite.find(:uuid => test_suite)[0]
      end
      tests = test_suite.test_cases
      tests_to_run = []
      tests.each do |t|
        if !t.executed?()
          tests_to_run << t
        end
      end
      distribute_test_cases(tests_to_run)
    end

    def await_results(test_suite_uuid)
      puts "INFO: Waiting for test results..."
      suite = TestSuite.find({"uuid" => test_suite_uuid})[0]
      unfinished_tests = suite.query_unfinished_tests
      while !unfinished_tests.empty?
        puts "INFO: Waiting some time for new test results (#{unfinished_tests.size} tests remaining)..."
        sleep 10
        unfinished_tests = suite.query_unfinished_tests
      end
    end

    def clean_hosts()
      Util.exec_in_parallel(all_hosts) do |h|
        h.clean()
      end
    end

    private

    def get_proxy(host)
      proxy = @host_proxies[host]
      if !proxy
        proxy = ToasterAppClient.new(host)
        @host_proxies[host] = proxy
      end
      return proxy
    end

  end
end
