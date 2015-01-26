require_relative '../../helper'
require_relative '../../../lib/citac/specification/parser'

describe Citac::ConfigurationSpecification do
  describe '::parse' do
    context 'spec of 3 resources without dependencies' do
      before :each do
        @spec = Citac::ConfigurationSpecification.parse ['3']
      end

      it 'should parse resource count' do
        expect(@spec.resource_count).to eq(3)
      end

      it 'should not have any dependencies' do
        expect(@spec.deps(1)).to be_empty
        expect(@spec.deps(2)).to be_empty
        expect(@spec.deps(3)).to be_empty
      end
    end

    context 'spec of 3 resources with dependencies 1->3 and 2->3' do
      before :each do
        @spec = Citac::ConfigurationSpecification.parse ['3', '3 1 2']
      end

      it 'should parse resource count' do
        expect(@spec.resource_count).to eq(3)
      end

      it 'should parse dependencies' do
        expect(@spec.deps(1)).to be_empty
        expect(@spec.deps(2)).to be_empty
        expect(@spec.deps(3)).to contain_exactly(1, 2)
      end
    end

    context 'spec of 3 resources with cyclic dependencies 1 -> 2 -> 3 -> 1' do
      it 'should raise error during parsing' do
        expect { Citac::ConfigurationSpecification.parse ['3', '2 1', '3 1', '1 3'] }.to raise_error
      end
    end
  end
end
