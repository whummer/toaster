require_relative '../../helper'
require_relative '../../../lib/citac/utils/exec'

describe Citac::Utils::Exec do
  describe '::run_get_output' do
    it 'should run and return output' do
      output = Citac::Utils::Exec.run 'echo 123'
      expect(output.strip).to eq('123')
    end

    it 'should raise error on failure' do
      expect{Citac::Utils::Exec.run 'false'}.to raise_error
    end

    it 'should not raise error when raising error disabled' do
      expect{Citac::Utils::Exec.run 'false', :raise_on_failure => false}.to_not raise_error
    end
  end
end