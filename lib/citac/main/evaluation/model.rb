require 'fileutils'
require_relative '../config'
require_relative '../../commons/utils/exec'
require_relative '../../commons/utils/colorize'

module Citac
  module Main
    module Evaluation
      TASK_TYPES = [:execute_regular, :execute_stepwise, :analyze, :generate_base, :generate_stg, :test_stg, :test_base]

      class TaskDescription
        attr_reader :type, :spec_id

        def initialize(type, spec_id)
          @type = type
          @spec_id = spec_id
        end

        def to_s
          "#{spec_id} (#{type})"
        end
      end
    end
  end
end