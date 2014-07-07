

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require 'toaster/util/blocking_map'
require "toaster/test/test_suite"
require "toaster/test/test_generator"
require "toaster/util/lxc"
require "toaster/util/config"
require "toaster/model/automation_run"
require "toaster/util/timestamp"
require "toaster/test/test_case"

include Toaster

module Toaster
  class TestRunner

    @last_start_time = 0
    @delay_between_tests = 6 # wait some seconds before starting next test
    @semaphore = Mutex.new
    @signal = ConditionVariable.new

    class << self
      attr_accessor :last_start_time, :delay_between_tests, :semaphore, :signal
    end

    def initialize(test_suite=nil, max_threads_active=nil, terminate_when_queue_empty=true)
      @test_suite = test_suite
      @max_threads_active = max_threads_active ? max_threads_active : 5
      @active_threads = []
      @terminate_when_queue_empty = terminate_when_queue_empty
      @request_queue = Queue.new
      @result_map = BlockingMap.new
      @local_semaphore = Mutex.new
      @received_requests = []
      @handled_requests = []
      if !terminate_when_queue_empty
        start_worker_threads()
      end
    end

    def start()
      start_worker_threads()
    end
    def start_worker_threads()
      current_num = 0
      @local_semaphore.synchronize do
        current_num = @active_threads.size
      end
      ((current_num)..(@max_threads_active-1)).each do 
        t = Thread.start {
          running = true
          while running
            begin
              test_case = nil
              @local_semaphore.synchronize do
                # terminate if no more requests are queued
                if @request_queue.empty? && @terminate_when_queue_empty
                  # do NOT add this check --> leads to busy wait loop!
                  #if @handled_requests.size >= @received_requests.size
                    running = false
                  #end
                end
                if running
                  test_case = @request_queue.pop()
                  @received_requests << test_case
                end
              end
              if test_case
                begin
                  automation_run = TestRunner.execute_test(test_case)
                  @result_map.put(test_case, automation_run)
                rescue Object => ex
                  err = "WARN: exception when running test case: #{ex}\n#{ex.backtrace.join("\n")}"
                  puts err
                  @result_map.put(test_case, err)
                end
                @local_semaphore.synchronize do
                  @handled_requests << test_case
                end
              end
            rescue Exception => ex
              puts "WARN: exception in test runner thread: #{ex}\n#{ex.backtrace.join("\n")}"
              @result_map.put(test_case, nil)
            end
          end
          @local_semaphore.synchronize do
            @active_threads.delete(self)
          end
        }
        @active_threads << t
      end
    end

    def stop()
      stop_threads()
    end
    def stop_threads()
      @active_threads.dup.each do |t|
        t.terminate()
        @active_threads.delete(t)
      end
    end

    def start_test_suite(blocking=true)

      start_worker_threads()

      @test_generator = TestGenerator.new(@test_suite) if @test_suite && !@test_generator

      @test_suite.save()

      # generate tests
      execute_tests(@test_generator.gen_all_tests())

      @test_suite.save()

    end

    def wait_until_finished(test_cases)
      test_cases = [test_cases] if !test_cases.kind_of?(Array)
      test_cases.dup.each do |t|
        # this operation will block until a results becomes available..
        @result_map.get(t)
      end
    end

    def self.schedule_tests(test_suite, test_case_uuids)
      runner = TestRunner.new(test_suite)
      runner.schedule_tests(test_suite, test_case_uuids)
      runner.start_worker_threads()
    end

    def schedule_tests(test_suite, test_case_uuids)
      test_cases = []
      test_case_uuids.each do |tc|
        if !tc.kind_of?(TestCase)
          tc = TestCase.find(:uuid => tc)[0]
        end
        test_cases << tc
      end
      test_cases.each do |tc|
        schedule_test_case(tc)
      end
    end

    def self.ensure_automation_exists_in_db(automation_name,
      recipes, test_suite, destroy_container=true, print_output=false)

      chef_node_name = ChefUtil.extract_node_name(automation_name)
      # prepare run list (add toaster::testing recipe definitions)
      actual_run_list = ChefUtil.prepare_run_list(chef_node_name, recipes)
      automation = Automation.find_by_name_and_runlist(automation_name, actual_run_list)
      return automation if !automation.nil?

      # if we don't have a matching automation in the DB yet, execute an initial run..
      c = TestCase.new(test_suite)
      test_suite.test_cases << c
      puts "INFO: Executing initial automation run; test case '#{c.uuid}'"
      automation_run = execute_test(c, automation_name, destroy_container, print_output)
      puts "DEBUG: Finished execution of initial automation run; test case '#{c.uuid}': #{automation_run}"
      return nil if !automation_run
      return automation_run.automation
    end

    def schedule_test_case(test_case)
      execute_test_case(test_case, false)
    end
    def execute_test_case(test_case, do_wait_until_finished=true)
      execute_tests(test_case, do_wait_until_finished)
    end
    def execute_tests(test_cases, do_wait_until_finished=true)
      test_cases = [test_cases] if !test_cases.kind_of?(Array)
      test_cases.each do |test|
        puts "INFO: Pushing test case to queue: #{test.uuid}"
        @request_queue.push(test)
      end

      # start worker threads (if they are not already running..)
      start_worker_threads()

      if do_wait_until_finished
        puts "INFO: Waiting until #{test_cases.size} test cases are finished."
        wait_until_finished(test_cases)
      end
    end

    #
    # execute the provided test case
    #
    def self.execute_test(test_case, automation_name=nil, 
        destroy_container=true, print_output=false, num_attempts=2)

      test_suite = nil
      test_id = nil
      recipes = nil
      self.semaphore.synchronize do
        test_suite = test_case.test_suite
        test_id = test_suite.uuid
        automation_name = test_suite.automation.get_short_name if !automation_name
        recipes = test_suite.automation.recipes
      end

      # generate automation attributes which represent this test case
      chef_node_attrs = test_case.create_chef_node_attrs()

      sleep_time = 0
      self.semaphore.synchronize do
        time = TimeStamp.now()
        diff = time - self.last_start_time
        if diff < self.delay_between_tests.to_f
          sleep_time = self.delay_between_tests.to_f - diff
        end
        self.last_start_time = time + sleep_time
      end

      # sleep a bit, and then this test is ready to go...
      sleep(sleep_time)
      time_now = TimeStamp.now()
      test_case.start_time = time_now

      # start test case execution
      automation_run = nil
      error_output = nil
      while num_attempts > 0
        begin
          automation_run = TestRunner.do_execute_test(automation_name,
              recipes, chef_node_attrs, test_suite.lxc_prototype, test_id, 
              destroy_container, print_output)

          test_case.test_suite().test_cases << test_case if !test_case.test_suite().test_cases().include?(test_case)
          test_case.automation_run = automation_run

          num_attempts = 0
        rescue Object => ex
          error_output = ex
          num_attempts -= 1
          puts "WARN: cannot run test case '#{test_case.uuid}' (remaining attempts: #{num_attempts}): #{ex}"
          puts "#{ex.backtrace.join("\n")}"
        end
      end

      if !automation_run
        machine_id = Util.get_machine_id()
        automation = test_case.test_suite.automation
        automation_run = AutomationRun.new(
          :automation => automation, 
          :machine_id => machine_id,
          :user => test_case.test_suite.user
        )
        puts "WARN: Test case '#{test_case.uuid}' failed entirely, storing " +
            "an empty automation run '#{test_case.automation_run}' with success=false."
        automation_run.success = false
        automation_run.end_time = TimeStamp.now
        automation_run.error_details = "Test case '#{test_case.uuid}' failed " +
            "(no automation run created by test runner). Output:\n#{error_output}"
        automation_run.save
        test_case.automation_run = automation_run
      end

      test_case.end_time = TimeStamp.now().to_i
      test_case.save

      return automation_run
    end

    private

    def self.prepare_test_container(lxc, automation_name, recipes)
      # apply some necessary preparations to the test container

      # copy config file from host into container
      config_file_host = "#{Dir.home}/.toaster"
      config_file_cont = "#{lxc['rootdir']}/root/.toaster"
      `cp '#{config_file_host}' '#{config_file_cont}'`

      `ssh #{lxc["ip"]} "gem install --no-ri --no-rdoc cloud-toaster 2>&1"`

    end

    def self.do_execute_test(automation_name, recipes, chef_node_attrs,
        prototype_name, test_id=nil, destroy_container=true, print_output=false, num_repeats=0)

      # Create/prepare new LXC container. 
      lxc = LXC.new_container(prototype_name)
      prepare_test_container(lxc, automation_name, recipes)

      recipes = [recipes] if !recipes.kind_of?(Array)
      automation_run = nil
      output = ""
      output_printed = false

      begin
        # create run list from list of recipe names
        run_list = recipes.collect { |r| r.include?("recipe[") ? r :
          "recipe[#{automation_name}::#{r}]" }

        # run chef automation within LXC container
        key = "runChef " + Util.generate_short_uid()
        TimeStamp.add(nil, key)
        output = LXC.run_chef_node(lxc, automation_name, run_list, chef_node_attrs)
        TimeStamp.add(nil, key)

        automation_run_id = nil
        pattern = /.*Current automation run ID:\s*([a-z0-9_\-]+)/
        output.scan(pattern) { |id| automation_run_id = id[0].strip }

        if !automation_run_id || !automation_run_id.match(/[a-zA-Z0-9_\-]+/)
          puts "WARN: Could not extract automation run ID from output of previous test case run ('#{automation_run_id}')."
          # repeat the process
          (1..num_repeats).each do |iteration|
            puts "INFO: Repeating test case '#{test_id}' - automation '#{automation_name}', run list '#{run_list}'"
            # create/prepate new container
            lxc_new = LXC.new_container(prototype_name)
            prepare_test_container(lxc_new, automation_name, recipes)

            output = LXC.run_chef_node(lxc_new, automation_name, run_list, chef_node_attrs)
            output.scan(pattern) { |id| automation_run_id = id[0].strip }
            if destroy_container
              LXC.destroy_container(lxc_new)
            end
            if automation_run_id && automation_run_id.match(/[a-zA-Z0-9_\-]+/)
              break
            end
          end
        end

        if print_output
          puts "Output: #{output} <<=="
          output_printed = true
        end

        if automation_run_id
          automation_run = AutomationRun.load(automation_run_id)
          if test_id
            if !automation_run.automation
              #automation_run.automation = Automation.load(automation_run.automation_id)
              puts "WARN: no automation associated with automation run UUID '#{automation_run.uuid}'."
            else
              auto = automation_run.automation
              if !auto.chef_run_list || auto.chef_run_list.empty?
                chef_node = ChefUtil.extract_node_name(automation_name)
                auto.chef_run_list = [].concat(ChefUtil.prepare_run_list(chef_node, run_list))
                auto.save
              end
            end
          end
        end

      rescue Exception => ex
        puts "ERROR: #{ex} - #{ex.backtrace.join("\n")}"
      end

      # completely destroy the container and delete its contents
      if destroy_container
        key = "lxcDestroy " + Util.generate_short_uid()
        TimeStamp.add(nil, key)
        LXC.destroy_container(lxc)
        TimeStamp.add(nil, key)
      end

      if !automation_run
        if print_output && !output_printed
          puts "Output: #{output} <<==="
        end
        #raise "Could not extract automation run ID from test run (tried #{1+num_repeats} times)"
        raise output
      end

      return automation_run
    end

  end
end
