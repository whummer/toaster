require 'stringio'

module Citac
  module Model
    class ChangeTrackingSettings
      attr_accessor :file_exclusion_patterns, :state_exclusion_patterns, :start_markers,
                    :end_markers, :command_generated_trace_file, :passthrough_output

      def initialize
        @file_exclusion_patterns = []
        @state_exclusion_patterns = []
        @start_markers = []
        @end_markers = []
        @command_generated_trace_file = nil
        @passthrough_output = false
      end
    end

    class ChangeSummary
      attr_reader :changes, :additional_data

      def initialize
        @changes = Array.new
        @additional_data = Hash.new
      end

      def to_s
        if @changes.empty?
          'No changes.'
        else
          result = StringIO.new
          result.puts "#{@changes.size} changes:"
          @changes.each {|c| result.puts "  #{c}"}
          result.string
        end
      end
    end

    class Change
      attr_reader :category, :type, :subject
      attr_accessor :old_value, :new_value

      def initialize(category, type, subject)
        @category = category
        @subject = subject
        @type = type

        @old_value = nil
        @new_value = nil
      end

      def to_s
        value_diff = ''
        value_diff = ": '#{@old_value}'" unless @old_value.nil?
        unless @new_value.nil?
          if @old_value.nil?
            value_diff = ": '#{@new_value}'"
          else
            value_diff << " -> '#{@new_value}'"
          end
        end

        "#{category}/#{type}: #{subject}#{value_diff}"
      end
    end
  end
end