

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/markup/markup_util"
require "toaster/state/system_state"

include Toaster

module Toaster
  class Convergence

    def self.convergence_for_automation(automation, prop_value_percentage_threshold=0.7)
      conv_props = {}
      conv_props_list = []
      TimeStamp.add(nil, "conv_for_auto")
      # NOTE: our assumption here is that the tasks 
      # are returned in sequential order..!
      tasks = automation.get_globally_executed_tasks()
      tasks.each_with_index do |task,task_index|
        convergence_for_task(task, prop_value_percentage_threshold).each do |conv_prop|
          prop_name = conv_prop[0]
          if conv_props[prop_name] && conv_props[prop_name] != conv_prop
            #puts "INFO: Overwriting convergent property '#{prop_name}' with new value: #{conv_props[prop_name]} => #{conv_prop}"
          end
          conv_props[prop_name] = conv_prop
        end
        #conv_props.concat(convergence_for_task(task))
        conv_props_list = conv_props.values
        #conflicts = get_prop_conflicts(conv_props_list)
        #if !conflicts.empty?
        #  puts "WARN: found conflicting properties in convergence: #{conflicts.inspect}"
        #end
      end
      TimeStamp.add_and_print("compute convergence of automation", nil, "conv_for_auto") { |duration| duration > 15 }
      return conv_props_list
    end

    def self.convergence_for_task(task, prop_value_percentage_threshold=0.7)
      ch = task.global_state_prop_changes
      ps = task.global_post_states
      # eliminate inserted map entries in post states
      ps.each do |p|
        MarkupUtil.eliminate_inserted_map_entries!(p)
      end
      # remove ignored properties from post states
      ignore_props = SystemState.read_ignore_properties()
      ps.each do |p|
        SystemState.remove_ignore_props!(p, ignore_props)
      end
      # remove ignored properties from state changes
      SystemState.remove_ignore_props!(ch, ignore_props)

      return convergence_for_prop_changes(ch, ps, prop_value_percentage_threshold)
    end

    #
    # Args:
    #  - prop_changes: Should contain an array of 
    #       Toaster::StatePropertyChange objects.
    #  - post_states: Total collection of post-states
    #  - min_percentage: minimum occurrence percentage (over 
    #       all post-states) required for a property to be 
    #       considered as convergent.
    # 
    def self.convergence_for_prop_changes(prop_changes, 
        post_states, min_percentage=0.5)
      candidates = get_convergence_candidates(prop_changes)
      result = []
      candidates.each do |prop|
        property_name = prop[0]
        value = prop[1]
        values_equal = get_states_equal(post_states, property_name, value)
        percentage = values_equal.size.to_f / post_states.size.to_f
        if percentage >= min_percentage
          new_val = [property_name, value, percentage, values_equal.size, post_states.size]
          if !result.include?(new_val)
            result << new_val
          end
        end
      end
      return result
    end

    def self.get_convergence_candidates(prop_changes)
      cands = Set.new
      prop_changes.each do |pc|
        value = pc.action == StatePropertyChange::ACTION_DELETE ? nil : 
                pc.action == StatePropertyChange::ACTION_INSERT ? pc.value :
                pc.action == StatePropertyChange::ACTION_MODIFY ? pc.value : nil;
        cands << [pc.property, value, pc.task_execution.start_time]
      end
      return cands
    end

    def self.get_states_equal(post_states, property_name, value)
      result = []
      post_states.each do |ps|
        value1 = nil
        error = nil
        begin
          value1 = MarkupUtil.get_value_by_path(ps, property_name)
        rescue => ex
          error = ex
        end
        if !value.nil? && value1.nil?
          error_text = "#{error}"
          #puts "Expected value on property evaluation, but got exception: #{error_text[0..200]}..."
          #puts "Property change: #{property_name}"
        elsif value.nil? && !value1.nil?
          # raise "Expected exception on property evaluation, but got value: #{value1}"
        end
        if value == value1 || value.eql?(value1)
          result << ps
        end
      end
      return result
    end

    #
    # Args:
    #   - prop_values: list of Toaster::StateProperty objects
    #
    def self.get_prop_conflicts(prop_values)
      confl = []
      for i in (0..(prop_values.size - 1))
        for j in ((i+1)..(prop_values.size - 1))
          p1_key = prop_values[i][0]
          p2_key = prop_values[j][0]
          p1_value = prop_values[i][1]
          p2_value = prop_values[j][1]
          if p1_key == p2_key
            if p1_value != p2_value
              confl << [p1_key,p1_value,p2_value]
            end
          end
        end
      end
      return confl
    end

    # automation_run --> prop_key --> list of (task_execution,prop_value)
    def self.execution_traces(automation, property_patterns)
      tmp = {}
      task_execs = automation.get_task_execs_by_run
      # list of property keys
      prop_keys = Set.new
      # build tmp result hash
      task_execs.each do |run,exes|
        tmp[run] = {}
        exes.unshift(TaskExecution.new(nil,nil,nil,[],"start"))
        exes.each_with_index do |exe,idx|
          if exe.kind_of?(TaskExecution)
            pre_state = MarkupUtil.clone(exe.state_before) || {}
            post_state = MarkupUtil.clone(exe.state_after) || {}
            MarkupUtil.eliminate_inserted_map_entries!(pre_state)
            MarkupUtil.eliminate_inserted_map_entries!(post_state)
            pres = SystemState.get_flat_attributes(pre_state)
            posts = SystemState.get_flat_attributes(post_state)
            pres.each do |pre,pre_val|
              if Util.match_any(pre, property_patterns)
                prop_keys << pre
                tmp[run][pre] = {} if !tmp[run][pre]
                prev_exe = exes[idx - 1]
                tmp[run][pre][prev_exe.uuid] = MarkupUtil.get_value_by_path(pre_state, pre)
              end
            end
            posts.each do |post,post_val|
              if Util.match_any(post, property_patterns)
                prop_keys << post
                tmp[run][post] = {} if !tmp[run][post]
                tmp[run][post][exe.uuid] = MarkupUtil.get_value_by_path(post_state, post)
              end
            end
          end
        end
      end
      # build result hash
      result = {}
      task_execs.each do |run,exes|
        result[run] = {}
        prop_keys.each do |prop|
          result[run][prop] = []
          exes.each do |exe|
            uuid = exe.uuid
            exe = nil if exe.uuid == "start"
            result[run][prop] << [exe, tmp[run][prop][uuid]]
          end
        end
      end
      return result
    end

  end
end
