require_relative '../../helper'
require_relative '../../../lib/citac/core/core'
require_relative '../../../lib/citac/core/stg'

describe Citac::Core::DependencyGraph do
  describe '#to_stg' do
    it 'should generate simple stg' do
      specification = Citac::Core::DependencyGraph.from_confspec ['3']
      specification.add_dep 2, 3

      stg = specification.to_stg
      dot = stg.to_dot :node_label_getter => lambda { |n| n.label.join ', ' }
      #puts dot
    end

    it 'should generate advanced stg' do
      specification = Citac::Core::DependencyGraph.from_confspec ['5']
      specification.add_dep 2, 3
      specification.add_dep 4, 5

      stg = specification.to_stg
      dot = stg.to_dot :node_label_getter => lambda { |n| n.label.join ', ' }
      #puts dot
    end

    it 'should generate advanced stg 2' do
      specification = Citac::Core::DependencyGraph.from_confspec ['5']
      specification.add_dep 2, 4
      specification.add_dep 3, 4
      specification.add_dep 4, 5

      stg = specification.to_stg
      dot = stg.to_dot :node_label_getter => lambda { |n| n.label.join ', ' }
      #puts dot
    end

    it 'should generate indep stg with 5' do
      specification = Citac::Core::DependencyGraph.from_confspec ['5']

      stg = specification.to_stg
      dot = stg.to_dot :node_label_getter => lambda { |n| n.label.join ', ' }
      #puts dot
    end
  end
end
