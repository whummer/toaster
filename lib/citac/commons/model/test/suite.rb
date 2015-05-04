module Citac
  module Model
    class TestSuite
      attr_accessor :id
      attr_reader :name, :test_cases

      def initialize(name)
        @name = name
        @test_cases = Array.new
      end

      def test_case(case_id)
        @test_cases.find{|c| c.id == case_id}
      end

      def add_test_case(test_case)
        #TODO add to dep graph
        @test_cases << test_case
      end

      def finish
        #TODO order topologically and assign ids
        @test_cases.each_with_index do |test_case, idx|
          test_case.id = idx + 1
        end
      end
    end
  end
end