require_relative '../../helper'
require_relative '../../../lib/citac/specification/model'

describe Citac::ConfigurationSpecification do
  describe '#alldeps' do
    context 'with no dependencies' do
      before :each do
        @spec = Citac::ConfigurationSpecification.new 2
      end

      it 'should not contain any dependency' do
        expect(@spec.alldeps(1)).to be_empty
        expect(@spec.alldeps(2)).to be_empty
      end
    end

    context 'with dependency 1 -> 2' do
      before :each do
        @spec = Citac::ConfigurationSpecification.new 2
        @spec.add_dep 1, 2
      end

      it 'should contain direct dependency' do
        expect(@spec.alldeps(1)).to be_empty
        expect(@spec.alldeps(2)).to contain_exactly(1)
      end
    end

    context 'with transitive dependencies 1 -> 2 -> 3' do
      before :each do
        @spec = Citac::ConfigurationSpecification.new 3
        @spec.add_dep 1, 2
        @spec.add_dep 2, 3
      end

      it 'should contain direct dependencies' do
        expect(@spec.alldeps(1)).to be_empty
        expect(@spec.alldeps(2)).to include(1)
        expect(@spec.alldeps(3)).to include(2)
      end

      it 'should contain transitive dependencies' do
        expect(@spec.alldeps(3)).to contain_exactly(1, 2)
      end
    end

    context 'with transitive dependencies multiple times 1 -> 2 -> 3 and 1 -> 3' do
      before :each do
        @spec = Citac::ConfigurationSpecification.new 3
        @spec.add_dep 1, 2
        @spec.add_dep 2, 3
        @spec.add_dep 1, 3
      end

      it 'should contain direct dependencies' do
        expect(@spec.alldeps(1)).to be_empty
        expect(@spec.alldeps(2)).to include(1)
        expect(@spec.alldeps(3)).to include(2)
      end

      it 'should contain transitive dependencies' do
        expect(@spec.alldeps(3)).to contain_exactly(1, 2)
      end

      it 'should contain multiple dependencies once' do
        expect(@spec.alldeps(3).length).to eq(2)
      end
    end
  end
end