module Citac
  module Model
    class TestSuite
      STG_NAME_PATTERN = /^stg \(expansion = (?<expansion>[0-9]+), all edges = (?<alledges>(true)|(false)), coverage = (?<coverage>(edge)|(path)), edge limit = (?<edgelimit>[0-9]+)\)$/

      attr_accessor :id
      attr_reader :name, :test_cases

      def type
        @name =~ /stg/ ? :stg : :base
      end

      def stg_expansion
        match = STG_NAME_PATTERN.match @name
        raise "Unable to parse name: #{@name}" unless match

        match[:expansion].to_i
      end

      def stg_alledges
        match = STG_NAME_PATTERN.match @name
        raise "Unable to parse name: #{@name}" unless match

        match[:alledges] == 'true'
      end

      def stg_coverage
        match = STG_NAME_PATTERN.match @name
        raise "Unable to parse name: #{@name}" unless match

        match[:coverage].to_sym
      end

      def stg_edgelimit
        match = STG_NAME_PATTERN.match @name
        raise "Unable to parse name: #{@name}" unless match

        match[:edgelimit].to_i
      end

      def initialize(name)
        @name = name
        @test_cases = Array.new
      end

      def test_case(case_id)
        @test_cases.find{|c| c.id == case_id}
      end

      def add_test_case(test_case)
        @test_cases << test_case
      end

      def finish
        @test_cases.each_with_index do |test_case, idx|
          test_case.id = idx + 1
        end
      end

      def to_s
        "#{id}/#{name}"
      end
    end
  end
end