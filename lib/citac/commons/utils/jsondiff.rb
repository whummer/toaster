require 'hashdiff'
require 'json'

require_relative '../model/change_tracking'

module Citac
  module Utils
    module JsonDiff
      def self.diff(json1, json2, category)
        json1 = JSON.parse json1
        json2 = JSON.parse json2

        diffs = HashDiff.diff json1, json2
        diffs.map do |diff|
          case diff[0]
            when '+'
              change = Citac::Model::Change.new category, :added, diff[1]
              change.new_value = diff[2]
            when '-'
              change = Citac::Model::Change.new category, :removed, diff[1]
              change.old_value = diff[2]
            when '~'
              change = Citac::Model::Change.new category, :changed, diff[1]
              change.old_value = diff[2]
              change.new_value = diff[3]
            else
              change = Citac::Model::Change.new category, :unknown, diff.inspect
          end

          change
        end
      end
    end
  end
end