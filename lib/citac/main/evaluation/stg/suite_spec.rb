require_relative '../../../commons/model'

module Citac
  module Main
    module Evaluation
      module STG
        class SuiteSpec
          def self.from_suite(suite)
            return nil unless suite.type == :stg
            SuiteSpec.new suite.stg_coverage, suite.stg_edgelimit, suite.stg_expansion, suite.stg_alledges
          end
          
          attr_accessor :coverage, :edgelimit, :expand, :alledges

          def initialize(coverage, edgelimit, expand, alledges)
            @coverage = coverage
            @edgelimit = edgelimit
            @expand = expand
            @alledges = alledges
          end

          def hash
            [@coverage, @edgelimit, @expand, @alledges].hash
          end

          def eql?(other)
            @coverage == other.coverage && @edgelimit == other.edgelimit && @expand == other.expand && @alledges == other.alledges
          end
          alias_method :==, :eql?

          def to_s
            "#{coverage} - #{edgelimit} - #{expand} - #{alledges}"
          end
        end
      end
    end
  end
end