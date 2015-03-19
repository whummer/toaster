require_relative '../../helper'
require_relative '../../../lib/citac/core/dependency_graph'

describe Citac::Core::DependencyGraph do
  describe '#ancestors' do
    context 'with no dependencies' do
      before :each do
        @spec = Citac::Core::DependencyGraph.from_confspec ['2']
      end

      it 'should not contain any dependency' do
        expect(@spec.ancestors(1)).to be_empty
        expect(@spec.ancestors(2)).to be_empty
      end
    end

    context 'with dependency 1 -> 2' do
      before :each do
        @spec = Citac::Core::DependencyGraph.from_confspec ['2']
        @spec.add_dep 1, 2
      end

      it 'should contain direct dependency' do
        expect(@spec.ancestors(1)).to be_empty
        expect(@spec.ancestors(2)).to contain_exactly(1)
      end
    end

    context 'with transitive dependencies 1 -> 2 -> 3' do
      before :each do
        @spec = Citac::Core::DependencyGraph.from_confspec ['3']
        @spec.add_dep 1, 2
        @spec.add_dep 2, 3
      end

      it 'should contain direct dependencies' do
        expect(@spec.ancestors(1)).to be_empty
        expect(@spec.ancestors(2)).to include(1)
        expect(@spec.ancestors(3)).to include(2)
      end

      it 'should contain transitive dependencies' do
        expect(@spec.ancestors(3)).to contain_exactly(1, 2)
      end
    end

    context 'with transitive dependencies multiple times 1 -> 2 -> 3 and 1 -> 3' do
      before :each do
        @spec = Citac::Core::DependencyGraph.from_confspec ['3']
        @spec.add_dep 1, 2
        @spec.add_dep 2, 3
        @spec.add_dep 1, 3
      end

      it 'should contain direct dependencies' do
        expect(@spec.ancestors(1)).to be_empty
        expect(@spec.ancestors(2)).to include(1)
        expect(@spec.ancestors(3)).to include(2)
      end

      it 'should contain transitive dependencies' do
        expect(@spec.ancestors(3)).to contain_exactly(1, 2)
      end

      it 'should contain multiple dependencies once' do
        expect(@spec.ancestors(3).length).to eq(2)
      end
    end
  end
end