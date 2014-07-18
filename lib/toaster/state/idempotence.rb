

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/markup/markup_util"

include Toaster

module Toaster
  class Idempotence

    def initialize(test_suite_or_automation)
      if test_suite_or_automation.kind_of?(Automation)
        @automation = test_suite_or_automation
        @test_cases = @automation.get_all_test_cases
      else
        @automation = test_suite_or_automation.automation
        @test_cases = test_suite_or_automation.test_cases
      end
      @repeated_task_execs = nil
      @non_idempotent_tasks_details = nil
      @non_idempotent_taskseqs_details = nil
    end

    def non_idempotent_task_seq(consider_success_of_tasks=false)
      result = []
      non_idempotent_taskseqs_details(consider_success_of_tasks).each do |tsk,details|
        result << tsk
      end
      return result
    end

    def non_idempotent_tasks(consider_success_of_tasks=true)
      result = []
      non_idempotent_tasks_details(consider_success_of_tasks).each do |tsk,details|
        result << tsk
      end
      return result
    end

    # returns:
    # task_seq -> test_case -> ["execs"] -> [seq_of_task_exections ...]
    # task_seq -> test_case -> ["changes"] -> seq_of_task_exections -> [state_changes ...]
    def non_idempotent_taskseqs_details(consider_success_of_tasks=false)
      return @non_idempotent_taskseqs_details if @non_idempotent_taskseqs_details
      result = {}
      repeated_task_executions().each do |tc,task_array_to_execs|
        task_array_to_execs.each do |task_array,execs|

          task_array = task_array.collect { |t_uuid| Task.find("uuid"=>t_uuid)[0] }

          execs.each_with_index do |exec_seq,idx|
            pre_state = MarkupUtil.clone(exec_seq[0].state_before)
            MarkupUtil.eliminate_inserted_map_entries!(pre_state)
            post_state = SystemState.reconstruct_state_from_execs_seq(exec_seq)
            #puts "DEBUG: comparing pre-state and reconstructed post-state:\n#{pre_state}\n#{post_state}"
            state_changes = SystemState.get_state_diff(pre_state, post_state)
            SystemState.remove_ignore_props!(state_changes)

            if state_changes.empty? && idx == 0
              # non_state_change_tasks << task_array
            elsif idx > 0
              # an idempotent task (sequence) should:
              # - not yield a state change after first execution
              # - always yield a success if the first run was successful
              if !state_changes.empty? || 
                (consider_success_of_tasks && 
                  (execs[idx-1][-1].success && !exec_seq[-1].success))
                # we need to be careful here: for some reason we have seen cases where
                # rel_start_time is negative (!) which is in fact impossible. Hence, we leave
                # out those cases until this problem is resolved, to be on the safe side..
                rel_start_time = exec_seq[0].start_time - tc.automation_run.start_time
                if rel_start_time >= 0
                  task_array_uuids = task_array.collect{|tmp| tmp.uuid}
                  puts "INFO: Non-idempotence detected in repeated " +
                    "execution of task sequence #{task_array_uuids} in test case #{tc.uuid}:\n--> #{state_changes}"
                  result[task_array] = {} if !result[task_array]
                  result[task_array][tc] = {} if !result[task_array][tc]
                  result[task_array][tc]["execs"] = [] if !result[task_array][tc]["execs"]
                  result[task_array][tc]["changes"] = {} if !result[task_array][tc]["changes"]
                  # add first execution sequence, if not yet added 
                  result[task_array][tc]["execs"] << execs[idx-1] if result[task_array][tc]["execs"].empty?
                  # add next execution sequence
                  result[task_array][tc]["execs"] << exec_seq
                  result[task_array][tc]["changes"][exec_seq] = state_changes
                else
                  puts "WARN: Start time of task execution '#{exec_seq[0].uuid}' " +
                    "(#{exec_seq[0].start_time}) is before automation run start time " +
                    "(#{tc.automation_run.start_time})!"
                end
              end
            end
          end
        end
      end
      @non_idempotent_taskseqs_details = result
      return result
    end

    # returns:
    # task -> test_case -> list_of_task_exections
    def non_idempotent_tasks_details(consider_success_of_tasks=true)
      return @non_idempotent_tasks_details if @non_idempotent_tasks_details
      result = {}
      non_state_change_tasks = Set.new
      repeated_task_executions().each do |tc,task_array_to_execs|
        task_array_to_execs.each do |task_array,execs|
          execs.each_with_index do |exec_sequence,idx|
            exec_sequence.each_with_index do |exec,task_idx_in_sequence|
              # get "relevant" state changes (without ignored  
              # properties such as file modification time etc)
              state_changes = exec.relevant_state_changes
              if state_changes.empty? && idx == 0
                non_state_change_tasks << exec.task
              elsif idx > 0
                # an idempotent task should:
                # - not yield a state change after first execution
                # - always yield a success if the first run was successful
                if !state_changes.empty? || 
                  (consider_success_of_tasks && 
                    (execs[idx-1][task_idx_in_sequence].success && !exec.success))
                  # we need to be careful here: for some reason we have seen cases where
                  # rel_start_time is negative (!) which is in fact impossible. Hence, we leave
                  # out those cases until this problem is resolved, to be on the safe side..
                  rel_start_time = exec.start_time - tc.automation_run.start_time
                  if rel_start_time >= 0
                    puts "INFO: Non-idempotence: State changes detected in repeated execution of task uuid #{exec.task.uuid} in test case #{tc.uuid}"
                    result[exec.task] = {} if !result[exec.task]
                    result[exec.task][tc] = [] if !result[exec.task][tc]
                    # add first execution, if not yet added 
                    result[exec.task][tc] << execs[idx-1][task_idx_in_sequence] if result[exec.task][tc].empty?
                    # add next execution
                    result[exec.task][tc] << exec
                  else
                    puts "WARN: Start time of task execution '#{exec.uuid}' (#{exec.start_time}) is before automation run start time (#{tc.automation_run.start_time})!"
                  end
                end
              end
            end
          end
        end
      end
      non_state_change_task_uuids = non_state_change_tasks.collect() { |t| t.uuid }
      puts "DEBUG: No state change detected in first execution of #{non_state_change_tasks.size} tasks:" if !non_state_change_tasks.empty?
      non_state_change_tasks.each do |task|
        puts task.name
#          puts task.sourcecode
#          puts "--------------"
      end
      puts "--------------"
      @non_idempotent_tasks_details = result
      return result
    end

    # returns:
    # test_case_id --> task_combination --> [task_execution_list ...]
    def repeated_task_executions()
      return @repeated_task_execs if @repeated_task_execs
      result = {}
      tasks = {}
      @test_cases.each do |tc|
        if tc.automation_run
          tc.repeat_task_uuids.each do |rt|
            #puts "#{rt.inspect}"
            rt = [rt] if !rt.kind_of?(Array)
            tc_id = tc #tc.uuid
            result[tc_id] = {} if !result[tc_id]
            result[tc_id][rt] = [] if !result[tc_id][rt]
            rt.each do |repeated_task|
              #execs = tc.task_executions(repeated_task)
              #tasks[repeated_task] = Task.find("uuid"=>repeated_task)[0] if !tasks[repeated_task]
              tasks[repeated_task] = @automation.get_task(repeated_task, true)
              #puts "===> #{tasks[repeated_task]}"
              execs = TaskExecution.find(
                  :task_id => tasks[repeated_task].id, 
                  :automation_run_id => tc.automation_run.id
              )
              execs.sort! { |a,b|
                a.start_time <=> b.start_time
              }
              execs.each_with_index do |exec,idx|
                if result[tc_id][rt].size <= idx
                  result[tc_id][rt] << []
                end
                result[tc_id][rt][idx] << exec
              end
            end
          end
        end
      end
      @repeated_task_execs = result
      return result
    end

  end
end
