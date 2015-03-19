require_relative '../../helper'
require_relative '../../../lib/citac/docker/images'
require_relative '../../../lib/citac/docker/containers'

describe Citac::Docker, :explicit => true do
  describe '::run' do
    it 'should run docker image in container' do
      image = Citac::Docker.images.first
      output = Citac::Docker.run image, ['echo', 'Hello World']

      expect(output.output.strip).to eq('Hello World')
    end

    it 'should delete container' do
      size1 = Citac::Docker.containers.size

      image = Citac::Docker.images.first
      Citac::Docker.run image, 'true'

      size2 = Citac::Docker.containers.size
      expect(size2).to eq(size1)
    end

    it 'should raise error if running container failed' do
      image = Citac::Docker.images.first
      expect { Citac::Docker.run image, 'false' }.to raise_error
    end

    it 'should delete container after container failed' do
      size1 = Citac::Docker.containers.size

      image = Citac::Docker.images.first
      expect { Citac::Docker.run image, 'false' }.to raise_error

      size2 = Citac::Docker.containers.size
      expect(size2).to eq(size1)
    end

    it 'should mount directory from host' do
      directory = File.dirname __FILE__
      file = File.basename __FILE__

      image = Citac::Docker.images.first
      output = Citac::Docker.run image, ['ls', '-l', '/asdf'], :mounts => [[directory, '/asdf', false]]
      expect(output.output).to include(file)
    end
  end
end