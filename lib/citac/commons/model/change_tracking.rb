require 'stringio'

module Citac
  module Model
    class ChangeTrackingSettings
      attr_accessor :exclusion_patterns, :start_markers, :end_markers

      def initialize
        @exclusion_patterns = []
        @start_markers = []
        @end_markers = []
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

      def initialize(category, type, subject)
        @category = category
        @subject = subject
        @type = type
      end

      def to_s
        "#{category}/#{type}: #{subject}"
      end
    end
  end
end