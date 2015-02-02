require_relative '../../helper'
require_relative '../../../lib/citac/environments/docker'

describe Citac::Environments::DockerEnvironmentManager, :explicit => true do
  before :each do
    @em = Citac::Environments::DockerEnvironmentManager.new
  end

  describe '#environments' do
    it 'should list all installed environments' do
      envs = @em.environments
      envs.each do |env|
        puts env.inspect
      end
    end
  end

  describe '#run' do
    it 'should run script in container' do
      env = @em.environments.first

      Dir.mktmpdir do |dir|
        script_path = File.join dir, 'script.sh'
        IO.write script_path, "#!/bin/sh\necho Hello from the script"

        output = @em.run env, script_path
        output.strip!

        expect(output).to eq('Hello from the script')
      end
    end

    it 'should mount citac' do
      env = @em.environments.first

      Dir.mktmpdir do |dir|
        script_path = File.join dir, 'script.sh'
        IO.write script_path, "#!/bin/sh\nwhich citac"

        output = @em.run env, script_path
        output.strip!

        expect(output).to eq('/opt/citac/bin/citac')
      end
    end
  end
end