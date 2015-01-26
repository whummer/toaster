require_relative '../../helper'
require_relative '../../../lib/citac/stg/stg'
require_relative '../../../lib/citac/specification/model'

describe 'stg generation' do
  it 'should generate simple stg' do
    specification = Citac::ConfigurationSpecification.new 3
    specification.add_dep 2, 3

    stg = Citac.generate_stg specification
    dot = stg.to_dot :node_label_getter => lambda {|n| n.label.join ', '}
    #puts dot
  end

  it 'should generate advanced stg' do
    specification = Citac::ConfigurationSpecification.new 5
    specification.add_dep 2, 3
    specification.add_dep 4, 5

    stg = Citac.generate_stg specification
    dot = stg.to_dot :node_label_getter => lambda {|n| n.label.join ', '}
    #puts dot
  end

  it 'should generate advanced stg 2' do
    specification = Citac::ConfigurationSpecification.new 5
    specification.add_dep 2, 4
    specification.add_dep 3, 4
    specification.add_dep 4, 5

    stg = Citac.generate_stg specification
    dot = stg.to_dot :node_label_getter => lambda {|n| n.label.join ', '}
    #puts dot
  end

  it 'should generate indep stg with 5' do
    specification = Citac::ConfigurationSpecification.new 5

    stg = Citac.generate_stg specification
    dot = stg.to_dot :node_label_getter => lambda {|n| n.label.join ', '}
    #puts dot
  end
end