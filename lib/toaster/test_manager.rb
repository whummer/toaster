

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/state/system_state"
require "toaster/state/syscall_tracer"
require "toaster/markup/markup_util"
require "toaster/model/task"
require "toaster/model/task_execution"
require "toaster/test/test_runner"
require "toaster/db/db"
require "toaster/util/config"
require "toaster/test/test_suite"
require "toaster/util/timestamp"
require "toaster/chef/resource_inspector"
require "toaster/chef/chef_util"

include Toaster

module Toaster
  class TestManager

    def initialize(config = {})
      @states = {}
      @current_executions = {}
      @cookbook_paths = config["cookbook_paths"] || []
      @transfer_state_config = false
      host = "localhost"
      TestManager.init_db(config)
      run = AutomationRun.new(nil, Util.get_machine_id())
      AutomationRun.set_current(run)

      if config["task_execution_timeout"]
        ChefListener.task_execution_timeout = config["task_execution_timeout"]
      end
      if config["task_exec_timeout_repeated"]
        ChefListener.task_exec_timeout_repeated = config["task_exec_timeout_repeated"] 
      end
      if config["rest_timeout"]
        Chef::Config[:rest_timeout] = config["rest_timeout"] 
      end
      if !config["transfer_state_config"].nil?
        @transfer_state_config = config["transfer_state_config"]
      end

      # Leave this output line unchanged - it is later extracted and parsed by
      # test_runner.rb, which needs to be able to determine the automation run ID.
      # This is a bit hacky, but seemed to be the best/fastest way to solve this.
      puts "INFO: Current automation run ID: #{AutomationRun.get_current.id}"

      @automation_name = config["automation_name"] || ""
      @recipes = config["recipes"] || []
      @skip_tasks = config["skip_tasks"] || []
      @repeat_tasks = config["repeat_tasks"] || []
      @repeated_tasks = []
      @state_change_config = {}

      @state_observer_thread = nil
    end

    #
    # Return the number of times a given task should be executed.
    # The result is usually 1 (default), or 0 (skip task) or 2 (repeat task once)
    #
    def num_requested_task_executions(task)
      return 0 if @skip_tasks.include?(task.uuid)
      return 2 if @repeat_tasks.include?(task.uuid)
      return 1
    end

    def tasks_to_repeat_now(last_executed_task)
      uuid = last_executed_task.kind_of?(String) ? last_executed_task : last_executed_task.uuid
      @repeat_tasks.each do |list|
        if list.kind_of?(Array)
          if !@repeated_tasks.include?(list)
            if list[-1] == uuid
              @repeated_tasks << list
              return list
            end
          end
        end
      end
      return nil
    end

    #
    # called by chef_listener BEFORE a chef resource (task) is executed
    # by Chef's Runner::run_action method.
    #
    def before_run_action(task, execution_uuid)
      # indicate whether or not this task should be started/continued
      return false if @skip_tasks.include?(task.uuid)

      # clear the old state change config, if needed
      if !@transfer_state_config
        @state_change_config = {}
      end

      # get additional_state_configs from automation
      automation = AutomationRun.get_current().automation
      add_automation_specific_state_config(@state_change_config)

      # determine which parameters the task code accesses:
      task.parameters = ResourceInspector.get_accessed_parameters(task)
      task = task.save

      if execution_uuid
        @state_change_config = ResourceInspector.get_config_for_potential_state_changes(
            task, @cookbook_paths, @state_change_config)
        state = SystemState.get_system_state(@state_change_config)
        execution = TaskExecution.new(task, state, nil, nil, execution_uuid)
        execution.automation_run = AutomationRun.get_current()
        execution.sourcecode = ChefUtil.runtime_resource_sourcecode(task.resource_obj)
        @current_executions[execution_uuid] = execution

        # use the external ptrace-based program to monitor the Chef execution 
        # for changes in the file system (implemented via syscall hooks)
        if !@state_tracer
          @state_tracer = SyscallTracer.new()
        end
        @state_tracer.start

      end

      return true
    end

    #
    # called by chef_listener AFTER a chef resource (task) has been executed
    # by Chef's Runner::run_action method.
    #
    def after_run_action(task, execution_uuid, error = nil, script_output = nil)
      s_before = nil
      s_after = nil
      begin
        if !execution_uuid || !@current_executions[execution_uuid]
          # "init_chef_listener" is part of a special resource name which 
          # performs the AOP based instrumentation of the Chef run
          if !task.resource.to_s.include?("init_chef_listener")
            puts "WARN: Unable to find previous state for task execution " +
              "UUID '#{execution_uuid}' in 'after_run_action' " +
              "(This may be NORMAL within the context of a Chef notification execution). " +
              "Currently active executions: #{@current_executions.inspect}"
          end
          return
        end


        # pause/stop monitoring
        add_prestate = @state_tracer.dump_execution_prestate
        add_state_change_config = SystemState.get_statechange_config_from_state(add_prestate)
        @state_tracer.stop

        # get additional_state_configs from automation
        add_automation_specific_state_config(@state_change_config)

        @state_change_config = ResourceInspector.get_config_for_potential_state_changes(
            task, @cookbook_paths, @state_change_config)

        # add additional state change configs from state tracer
        MarkupUtil.rmerge!(@state_change_config, add_state_change_config, true)

        if @state_change_config.empty?
          puts "WARN: Empty state change config for task UUID #{task.uuid}:\n#{task.sourcecode}\n------"
        end
        state = SystemState.get_system_state(@state_change_config)
        execution = @current_executions[execution_uuid]
        @current_executions.delete(execution_uuid)

        # add additional pre-states from state tracer
        MarkupUtil.rmerge!(execution.state_before, add_prestate, true)

        execution.end_time = TimeStamp.now().to_i
        execution.script_output = script_output
        execution.reduce_and_set_state_after(state)
        execution.success = error.nil?
        error = "#{error}\n" + "#{error.backtrace.join("\n")}" if error.respond_to?("backtrace")
        execution.error_details = error

        # clone the state hashes
        s_before = MarkupUtil.clone(execution.state_before)
        s_after = MarkupUtil.clone(execution.state_after)

        puts "DEBUG: states before/after #{execution}: #{execution.state_before}\n/\n#{execution.state_after}"
        # compute state changes
        prop_changes = SystemState.get_state_diff(s_before, s_after)
        execution.state_changes = prop_changes
        puts "INFO: Property changes (#{prop_changes.size}): #{prop_changes.inspect}"

        # remove ignored properties (e.g., file modification time etc.)
        SystemState.remove_ignore_props!(execution.state_before)
        SystemState.remove_ignore_props!(execution.state_after)

        # mongodb does not allow special chars like "." in the JSON hash
        MarkupUtil.rectify_keys(execution.state_before)
        MarkupUtil.rectify_keys(execution.state_after)

        execution = execution.save
      rescue => ex
        Util.print_backtrace(ex)
        puts "INFO: pre-state (original): #{s_before}"
        puts "INFO: post-state (original): #{s_after}"
        puts "INFO: pre-state: #{execution.state_before}"
        puts "INFO: post-state: #{execution.state_after}"
      end
    end

    def self.init_db(config)
      Config.init_db_connection(config)
    end

    def self.init_test(automation_name, recipes = [], test_id = nil, 
        prototype="default", destroy_container=true, print_output=false)
      test_id = test_id || Util.generate_short_uid()
      suite = TestSuite.find({"uuid" => test_id})
      return suite if suite && suite.size > 0
      suite = TestSuite.new(nil, recipes, test_id, prototype)
      suite.save
      automation = TestRunner.ensure_automation_exists_in_db(
        automation_name, recipes, suite, destroy_container, print_output)
      if !automation
        puts "WARN: Could not ensure that automation '#{automation_name}' exists in DB." 
        return nil
      end
      suite.automation = automation
      suite.save
      return suite
    end

    def self.run_tests(test_suite, blocking = true)
      if !test_suite.kind_of?(TestSuite)
        test_suite = TestSuite.find({"uuid" => test_suite})
      end
      if blocking
        runner = TestRunner.new(test_suite, nil, false)
        runner.start_test_suite(blocking)
        runner.stop
      else
        runner = TestRunner.new(test_suite, nil, true)
        runner.start_test_suite(blocking)
        runner.start_worker_threads()
      end
    end

    private

    def add_automation_specific_state_config(state_change_config, automation=nil)
      # ensure automation is set
      automation = AutomationRun.get_current().automation if !automation

      if automation.additional_state_configs &&
          !automation.additional_state_configs.empty?
        puts "INFO: Register additional state change configs for automation " + 
            "'#{automation.uuid}': #{automation.additional_state_configs}"
        # Make sure we clone the hash, otherwise the values from
        # state_change_config get propagated into automation.additional_state_configs..!
        add = MarkupUtil.clone(automation.additional_state_configs)
        # recursively merge state change configs
        MarkupUtil.rmerge!(state_change_config, add)
      end
    end

  end
end
