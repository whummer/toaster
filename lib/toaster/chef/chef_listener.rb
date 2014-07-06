

require 'toaster/util/util'
require 'toaster/chef/chef_util'
require 'toaster/markup/markup_util'
require 'toaster/model/automation'
require 'toaster/model/automation_run'
require 'json'
require 'chef/application/solo'
require 'chef/log'
require 'chef/runner'
require "toaster/util/timestamp"

include Toaster
include Aquarium::Aspects

module Toaster
  #
  # Performs AOP-based instrumentation of the Chef runtime and
  # registers listeners for lifecycle events during Chef automations.
  #
  # Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
  #
  class ChefListener
    # Informs about an automation task that is about to be executed.
    #
    # * *Args*    :
    #   - +task+ -> A Toaster::Task representing the currently executing task
    #   - +execution_uuid+ -> String that identifies the automation run this task is part of
    #
    def before_run_action(task, execution_uuid)
      # should be overridden by subclasses
    end

    # Informs about an automation task that has just been executed.
    #
    # * *Args*    :
    #   - +task+ -> A Toaster::Task representing the executed task
    #   - +execution_uuid+ -> String that identifies the automation run this task is part of
    #   - +error+ -> Contains details (usually an Exception object) in case an error has occurred
    #   - +script_output+ -> Contains output (stdout+stderr) of the script that executed the task
    #
    def after_run_action(task, execution_uuid, error = nil, script_output = nil)
      # should be overridden by subclasses
    end

    def self.add_listener(listener)
      register_aop_hook()
      self.active_listeners.push(listener)
    end

    # maps string -> task
    @tasks_by_uuid = {}
    # maps task -> joinpoint parameters
    @task_parameters = {}
    # maps resource -> task
    @tasks_by_resource = {}

    @active_listeners = []
    @repeated_tasks_running = false
    @task_exec_uuid_to_task = {}
    @task_exec_error = nil
    @current_task_exec_uuid = nil
    @initialized = false
    @toaster_chef_imported = false
    @chef_log_level = :info
    @task_execution_timeout = 60*20 # 20 minutes timeout per task
    @task_exec_timeout_repeated = 60*7 # timeout for tasks with retries
    @max_task_exec_retries = 2
    @repeat_resource_classes = [::Chef::Resource::RemoteFile,
                                ::Chef::Resource::Package,
                                ::Chef::Resource::GemPackage,
                                ::Chef::Resource::YumPackage,
                                ::Chef::Resource::AptPackage]

    class << self
      attr_accessor :active_listeners, :tasks_by_uuid, :task_parameters, 
        :repeated_tasks_running, :initialized, :toaster_chef_imported, 
        :chef_log_level, :task_execution_timeout, :task_exec_timeout_repeated,
        :max_task_exec_retries, :repeat_resource_classes, :tasks_by_resource,
        :current_task_exec_uuid, :task_exec_uuid_to_task, :task_exec_error
    end

    def self.get_task_from_sourcecode_line(resource, action, start_source_line)
      sourcecode = nil
      sourcefile = nil
      sourceline = nil
      if start_source_line
        # parse static resource definition source code
        sourcecode = ChefUtil.read_sourcecode(start_source_line)
        sourcefile = ChefUtil.get_sourcefile(start_source_line)
        begin sourcefile = sourcefile[(sourcefile.index("/")+1)..-1] end while sourcefile.scan("/").size > 2
        sourceline = ChefUtil.get_sourceline(start_source_line)
      end
      # get or create task
      task = Task.load_from_chef_source(resource, action, sourcecode, sourcefile, sourceline)
      return task
    end

    def self.get_task_list(chef_resource_list)
      list = []
      chef_resource_list.each do |r|
        resource = r.to_s
        action = r.action
        action = action[0] if action.kind_of?(Array)
        action = action.to_s if action.kind_of?(Symbol)
        start_source_line = r.source_line
        if !start_source_line
          puts "WARN: Could not read source_line from resource #{r}"
        end
        task = get_task_from_sourcecode_line(resource,action,start_source_line)
        list << task
      end
      return list
    end

    # this method is called ONCE, in the context of executing 
    # the first task of the automation under test
    def self.update_current_automation_info(run, ctx)
      node_name = nil
      chef_cfg = Chef::Config
      if chef_cfg[:json_attribs]
        json_file = chef_cfg[:json_attribs]
        if json_file.match(/.*\/[^\/]+_node\.json/).to_s == json_file
          node_name = json_file.gsub(/.*\/([^\/]+)_node\.json/, '\1')
          node_name = ChefUtil.wrap_node_name(node_name)
        elsif File.exist?(json_file)
          attribs = JSON.parse(File.read(json_file))
          node_name = attribs["toaster_node_name"] if attribs["toaster_node_name"]
        end
      else
        puts "WARN: Chef::Config[:json_attribs] is not available: '#{chef_cfg[:json_attribs]}'"
        node_name = chef_cfg[:node_name]
      end
      node_name = ctx.node.to_s if !node_name
      actual_node_name = node_name
      actual_node_name = node_name.gsub(/.*node\[(.+)\]/, '\1') if node_name.include?("node[")

      # try to retrieve automation from DB, if it exists..
      run_list = []
      ctx.node.run_list.each do |n|
        run_list << n.to_s
      end
      run.automation = Automation.find_by_name_and_runlist(node_name, run_list)[0]
      puts "TRACE: automation run #{run.uuid}, automation #{run.automation ? run.automation.uuid : 'nil'}"

      if !run.automation

        config_dir = File.join(File.dirname(__FILE__),"..")
        config_json = ::Toaster::Config.values()
        dirs = []
        config_json["chef"]["cookbook_dirs"].each do |dir|
          dir = File.expand_path(File.join(config_dir, dir)) if dir[0] != "/"
          dirs << dir
        end

        # important: due to possible name conflicts, all Chef related 
        # files apparently need to be loaded before chef_node_inspector, 
        # hence we put this require statement here.
        if !self.toaster_chef_imported
          require 'toaster/chef/chef_node_inspector'
          self.toaster_chef_imported = true
        end

        node_values = config_json["chef"]["node_values"]
        insp = Toaster::ChefNodeInspector.new(dirs,
                Toaster::DefaultProcessorRecursive.new(node_values) {
              |level, msg| puts "WARN: #{msg}" }) {
              |level, msg| puts "WARN: #{msg}"}
        recipe = ChefUtil.guess_recipe_from_runlist(run_list)
        params = {}
        begin
          params = insp.get_defaults(actual_node_name, recipe)
          puts "params: #{params}"
          # make sure we make the hash MongoDB-compatible 
          # (i.e., remove special characters in keys):
          MarkupUtil.rectify_keys(params)
        rescue Object => exc
          puts "WARN: Unable to get default parameters for recipe '#{actual_node_name}'-'#{recipe}': #{exc} - #{exc.backtrace}"
        end

        task_list = ChefListener.get_task_list(ctx.resource_collection.all_resources)
        run.automation = Automation.load_for_chef(node_name, task_list, params, run_list)
        #puts "TRACE: automation 1: #{node_name}, #{task_list}, #{params}, #{run_list}"
        #puts "TRACE: automation run 1: #{run.uuid}, automation #{run.automation ? run.automation.uuid : 'nil'}"

      end

      # determine active parameter values for the current automation run
      Automation.get_attribute_array_names(params, "").each do |param_array_path|
        val = nil
        if "#{param_array_path}" != ""
          eval("val = ctx.node#{param_array_path}")
          eval("params#{param_array_path} = val")
        end
      end
      run.run_attributes = RunAttribute.from_hash(params)
    end

    def self.save_current_run_details()
      run = AutomationRun.get_current()
      if run
        run.end_time = TimeStamp.now().to_i
        run.save

        # check if all executed tasks are also included
        # in the associated automation entity
        auto = run.automation
        if auto
          changed = false
          run.get_executed_tasks.each do |t|
            if !auto.get_task_ids.include?(t.uuid)
              auto.tasks << t
              changed = true
            end
          end
          auto.save if changed
        end
      end
    end

    def self.proceed_joinpoint_method(jp, task)

      # 16-characters short random ID should be enough for our purposes..
      execution_uuid = Util.generate_short_uid
      run = AutomationRun.get_current()

      # prepare task execution
      do_continue = prepare_task_exec(task, execution_uuid)

      if !do_continue

        puts "Skipping execution of task #{task.uuid} in automation run #{run.uuid}"

      else

        error = nil
        # we have to set the class-wide error variable as well,
        # because we need it later on to get the error of a
        # chef resource notification run  (TODO: revise)
        ChefListener.task_exec_error = nil # TODO

        begin
          ChefUtil.set_chef_log_level(self.chef_log_level)

          ################################
          # EXECUTE RESOURCE, WITH RETRIES
          ################################

          resource_to_exec = jp.context.parameters[0]
          resource_class = resource_to_exec.class
          exec_timeout = ChefListener.task_execution_timeout
          num_retries = 0
          if ChefListener.repeat_resource_classes.include?(resource_class)
            # set task execution timeout and retries
            exec_timeout = ChefListener.task_exec_timeout_repeated
            num_retries = ChefListener.max_task_exec_retries
          end
          (0..num_retries).each do |iter|
            begin 
              Util.exec_timeout(exec_timeout, ::Chef::Exceptions::CommandTimeout) do
                begin
                  self.current_task_exec_uuid = execution_uuid
                  self.task_exec_uuid_to_task[execution_uuid] = task
                  jp.proceed
                rescue Object => exc1
                  puts "WARN: Exception in resource execution: #{exc1} - backtrace (last 10 lines): #{exc1.backtrace[0..10]}"
                  raise exc1
                ensure
                  self.current_task_exec_uuid = nil
                end
              end
              break
            rescue ::Chef::Exceptions::CommandTimeout => exc
              # timeout occurred, start next try
              remaining = num_retries-iter
              if remaining > 0
                puts "WARN: Chef resource #{resource_to_exec} timed out, remaining retries: #{remaining}" 
                sleep 5 # sleep a bit before the next retry
              end
            end
          end

        rescue Object => ex
          error = ex
          puts "INFO: Error in Chef automation method. Adding details to testing log."
          run = AutomationRun.get_current()
          run.success = false
          run.end_time = TimeStamp.now().to_i
          run.error_details = "#{error}\n#{error.backtrace}"
          run.save()
        end

        # post-process task execution
        close_task_exec(task, execution_uuid, error, run)

        raise error if error
      end
    end

    def self.prepare_task_exec(task, execution_uuid)

      #puts "TRACE: Prepare task execution, task '#{task.name}', #{task.uuid}, execution #{execution_uuid}"

      # notify listeners
      do_continue = false
      self.active_listeners.each do |l|
        begin
          do_continue ||= l.before_run_action(task, execution_uuid)
        rescue Exception => ex
          puts "Error in listener method 'before_run_action': #{ex}"
          puts ex.backtrace
        end
      end

      return false if !do_continue

      # TODO: turn globals into class variables!
      $chef_log_level = ChefUtil.get_chef_log_level
      # redirect/capture STDOUT and STDERR!
      $output_io = StringIO.open('','w')
      $previous_stderr = $stderr
      $previous_stdout = $stdout
      $stdout.sync = true
      $stderr.sync = true
      $stderr = $output_io
      $stdout = $output_io
      script_output = nil

      return true
    end

    def self.close_task_exec(task, execution_uuid, error=nil, run=nil)

      run = AutomationRun.get_current() if !run

      # get output string
      script_output = $output_io.string
      # reset STDOUT and STDERR
      $stderr = $previous_stderr
      $stdout = $previous_stdout
      # print output
      puts script_output
      ChefUtil.set_chef_log_level($chef_log_level)

      # notify listeners
      self.active_listeners.each do |l|
        begin
          l.after_run_action(task, execution_uuid, error, script_output)
        rescue Exception => ex
          puts "Error in listener method 'after_run_action': #{ex}"
          puts ex.backtrace
        end
      end

    end

    def self.register_aop_hook1()
      Aspect.new :around, :calls_to => /^converge/,
      # :method_options => :exclude_ancestor_methods,
      :for_types => [Chef::Runner] do |jp, obj, *args|
        begin
          #puts "!!!!!!!!!!!!! AOP Chef::Runner::converge !!!!!!!!!!!!!!!!!!"
          # TODO FIXME uncomment as soon as this pointcut is fixed
          #ChefListener.save_current_run_details()
        end
      end
    end

    def self.register_aop_hook()

      return if self.initialized
      self.initialized = true

      register_aop_hook1()

      Aspect.new :around, :calls_to => /^run_action/,
      :for_types => [Chef::Runner],
      :method_options => :exclude_ancestor_methods do |jp, obj, *args|
        begin

          if jp.method_name.to_s == "run_action"

            # check to see if we need to update the 'current automation' object
            run = AutomationRun.get_current()
            if run && !run.automation
              ctx = obj.run_context
              ChefListener.update_current_automation_info(run, ctx)
            end

            # TODO: remove as soon as AOP pointcut for Chef::Runner.converge is working..
            ChefListener.save_current_run_details()

            resource = args[0]
            action = args[1]
            task = nil
            if ChefListener.tasks_by_resource[resource]
              task = ChefListener.tasks_by_resource[resource]
            else
              source_line_spec = ""
              args.each do |c| 
                if c.respond_to?("source_line")
                  #puts "DEBUG: AOP args in run_action: #{args}"
                  source_line_spec = c.source_line 
                  # this break here is vital!, because multiple source_line_spec's
                  # are read in this loop sometimes (in a Chef notifications context)
                  # and the FIRST element on the "args" array is the right resource
                  # we are looking for! For instance, we have seen arrays like the 
                  # following: [<notified_resource>, :run, :immediate, <notifying_resource>]
                  # TODO: check again, not sure if the statement above is true :/
                  break
                end
              end
              task = get_task_from_sourcecode_line(resource, action, source_line_spec)
              puts "get task #{resource} #{action} #{source_line_spec}: #{task}"
            end

            # check if we execute within an "immediate notification"
            if ChefListener.current_task_exec_uuid

              old_task = ChefListener.task_exec_uuid_to_task[ChefListener.current_task_exec_uuid]

              puts "INFO: Apparently we are running within a notification context; " + 
                "closing task execution (to re-open a new execution). " +
                "Old task: name '#{old_task.name}', uuid '#{old_task.uuid}'. " +
                "New task: name '#{task.name}', uuid '#{task.uuid}'."

              # close old/current task execution - a new one will be opened later in the process...
              close_task_exec(old_task, ChefListener.current_task_exec_uuid)

            end

            ChefListener.tasks_by_uuid[task.uuid] = task
            ChefListener.tasks_by_resource[resource] = task
            ChefListener.task_parameters[task] = jp.context.parameters

            num_executions = 1
            if !self.active_listeners.empty?
              num_executions = self.active_listeners[0].num_requested_task_executions(task)
            end

            # execute task, possibly multiple times...
            (1..num_executions).each do

              # run the actual Chef method that was intercepted by AOP..
              proceed_joinpoint_method(jp, task)

            end

            if !self.repeated_tasks_running
              # repeat sequences of tasks, as specified in repeat_tasks=[..] Chef configuration
              tasks_to_repeat = self.active_listeners[0].tasks_to_repeat_now(task)
              if tasks_to_repeat
                puts "INFO: List of tasks to repeat: #{tasks_to_repeat}"
                # temporarily disable interception (otherwise we end up in an infinite loop!)
                self.repeated_tasks_running = true
                tasks_to_repeat.each do |t_uuid|
                  task_to_run = self.tasks_by_uuid[t_uuid]
                  puts "INFO: Proceeding old joinpoint of task with uuid #{t_uuid}"
                  chef_runner = jp.context.advised_object
                  params = self.task_parameters[task_to_run]
                  # invoke method
                  begin
                    # this call will again be intercepted by AOP and we will 
                    # eventually end up in self.proceed_joinpoint_method(...)
                    # Hence, no exec_timeout block is required for this call.
                    chef_runner.run_action(params[0], params[1])
                  rescue Object => exc
                    puts "Error when repeating Chef resource: #{exc} - #{exc.backtrace}"
                  end
                end
                # re-activate interception
                self.repeated_tasks_running = false
              end
            end

          else

            begin
              jp.proceed
            rescue Object => ex
              puts "Error in Chef automation: #{ex}"
            end

          end
        rescue Object => ex1
          puts "Error occurred: #{ex1}"
          puts ex1.backtrace.join("\n") + "\n..."
        end
      end
    end

  end
end
