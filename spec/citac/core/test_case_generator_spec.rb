require_relative '../../helper'
require_relative '../../../lib/citac/core/dependency_graph'
require_relative '../../../lib/citac/core/formats/confspec'
require_relative '../../../lib/citac/core/test_case_generator'

describe Citac::Core::TestCaseGenerator do
  #
  # 1 -> 2 -> 3
  #      + -> 4
  #
  # 5 -> 6
  #
  before(:each) do
    @dg = Citac::Core::DependencyGraph.from_confspec ['6', '2 1', '3 2', '4 2', '6 5']
    @tcg = Citac::Core::TestCaseGenerator.new @dg
  end

  describe '#generate_idempotence_test' do
    it 'should generate test case for simple resource' do
      test_case = @tcg.generate_idempotence_test_case 5

      expect(test_case.steps.size).to eq(2)
      expect(test_case.steps[0].type).to eq(:exec)
      expect(test_case.steps[0].resource).to eq(5)
      expect(test_case.steps[1].type).to eq(:assert)
      expect(test_case.steps[1].resource).to eq(5)
    end

    it 'should generate test steps for dependencies' do
      test_case = @tcg.generate_idempotence_test_case 2

      expect(test_case.steps.size).to eq(3)
      expect(test_case.steps[0].type).to eq(:exec)
      expect(test_case.steps[0].resource).to eq(1)
      expect(test_case.steps[1].type).to eq(:exec)
      expect(test_case.steps[1].resource).to eq(2)
      expect(test_case.steps[2].type).to eq(:assert)
      expect(test_case.steps[2].resource).to eq(2)
    end

    it 'should generate test steps for multiple dependencies in correct order' do
      test_case = @tcg.generate_idempotence_test_case 3

      expect(test_case.steps.size).to eq(4)
      expect(test_case.steps[0].type).to eq(:exec)
      expect(test_case.steps[0].resource).to eq(1)
      expect(test_case.steps[1].type).to eq(:exec)
      expect(test_case.steps[1].resource).to eq(2)
      expect(test_case.steps[2].type).to eq(:exec)
      expect(test_case.steps[2].resource).to eq(3)
      expect(test_case.steps[3].type).to eq(:assert)
      expect(test_case.steps[3].resource).to eq(3)
    end
  end

  describe '#generate_preservation_test_case' do
    it 'should generate test case between two independent resources without ancestors' do
      test_case = @tcg.generate_preservation_test_case 1, 5

      expect(test_case.steps.size).to eq(3)
      expect(test_case.steps[0].type).to eq(:exec)
      expect(test_case.steps[0].resource).to eq(5)
      expect(test_case.steps[1].type).to eq(:exec)
      expect(test_case.steps[1].resource).to eq(1)
      expect(test_case.steps[2].type).to eq(:assert)
      expect(test_case.steps[2].resource).to eq(5)
    end

    it 'should generate test case between two independent resources, one with ancestors' do
      test_case = @tcg.generate_preservation_test_case 3, 5

      expect(test_case.steps.size).to eq(5)
      expect(test_case.steps[0].type).to eq(:exec)
      expect(test_case.steps[0].resource).to eq(5)
      expect(test_case.steps[1].type).to eq(:exec)
      expect(test_case.steps[1].resource).to eq(1)
      expect(test_case.steps[2].type).to eq(:exec)
      expect(test_case.steps[2].resource).to eq(2)
      expect(test_case.steps[3].type).to eq(:exec)
      expect(test_case.steps[3].resource).to eq(3)
      expect(test_case.steps[4].type).to eq(:assert)
      expect(test_case.steps[4].resource).to eq(5)
    end

    it 'should generate test case between two independent resources, both with ancestors' do
      test_case = @tcg.generate_preservation_test_case 3, 6

      expect(test_case.steps.size).to eq(6)
      expect(test_case.steps[0].type).to eq(:exec)
      expect(test_case.steps[0].resource).to eq(5)
      expect(test_case.steps[1].type).to eq(:exec)
      expect(test_case.steps[1].resource).to eq(6)
      expect(test_case.steps[2].type).to eq(:exec)
      expect(test_case.steps[2].resource).to eq(1)
      expect(test_case.steps[3].type).to eq(:exec)
      expect(test_case.steps[3].resource).to eq(2)
      expect(test_case.steps[4].type).to eq(:exec)
      expect(test_case.steps[4].resource).to eq(3)
      expect(test_case.steps[5].type).to eq(:assert)
      expect(test_case.steps[5].resource).to eq(6)
    end
  end

  describe '#generate_test_suite' do
    it 'should do' do
      test_cases = @tcg.generate_test_suite
      test_cases.each do |test_case|
        puts test_case
      end
    end
  end
end
