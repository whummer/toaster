require 'fileutils'
require_relative '../config'
require_relative '../../commons/utils/exec'
require_relative '../../commons/utils/colorize'

module Citac
  module Main
    module Evaluation
      TASK_TYPES = [:execute_regular, :execute_stepwise, :analyze, :generate_base, :generate_stg, :test_stg, :test_base]

      class TaskDescription
        attr_reader :type, :spec_id, :dir_name, :state

        def initialize(type, spec_id, dir_name, state)
          @type = type
          @spec_id = spec_id
          @dir_name = dir_name
          @state = state
        end

        def dir_name_pending
          "pending__#{@type}__#{@spec_id}.spec"
        end

        def dir_name_running
          "running__#{@type}__#{@spec_id}.spec"
        end

        def dir_name_finished
          index = TASK_TYPES.index @type

          if index + 1 < TASK_TYPES.size
            next_type = TASK_TYPES[index + 1]
            "pending__#{next_type}__#{@spec_id}.spec"
          else
            "finished__#{@spec_id}.spec"
          end
        end

        def dir_name_failed
          "failed__#{@type}__#{@spec_id}.spec"
        end

        def dir_name_cancelled
          "cancelled__#{@type}__#{@spec_id}.spec"
        end

        def to_s
          "#{@spec_id} (#{@type})"
        end
      end

      class TaskResult
        attr_accessor :result, :agent_name, :start_time, :end_time, :output

        def initialize(result, agent_name, start_time, end_time, output)
          @result = result
          @agent_name = agent_name
          @start_time = start_time
          @end_time = end_time
          @output = output
        end

        def to_s
          @output
        end
      end

      class TaskStatus
        attr_accessor :last_update, :agent_name

        def initialize(last_update, agent_name)
          @last_update = last_update
          @agent_name = agent_name
        end
      end
    end
  end
end