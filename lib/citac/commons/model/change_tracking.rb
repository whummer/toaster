require 'stringio'

module Citac
  module Model
    class ChangeTrackingSettings
      attr_accessor :file_exclusion_patterns, :state_exclusion_patterns, :start_markers, :end_markers, :command_generated_trace_file

      def initialize
        @file_exclusion_patterns = []
        @state_exclusion_patterns = []
        @start_markers = []
        @end_markers = []
        @command_generated_trace_file = nil
      end
    end

    class ChangeSummary
      attr_reader :changes, :touches, :additional_data

      def initialize
        @changes = Array.new
        @touches = Array.new
        @additional_data = Hash.new
      end

      def to_s
        result = StringIO.new

        if @changes.empty?
          result.puts 'No changes.'
        else
          result.puts "#{@changes.size} changes:"
          @changes.each {|c| result.puts "  #{c}"}
        end

        if @touches.empty?
          result.puts 'No touches.'
        else
          result.puts "#{@touches.size} touches:"
          @touches.each {|t| result.puts "  #{t}"}
        end

        result.string
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