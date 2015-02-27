require_relative '../../helper'
require_relative '../../../lib/citac/docker/images'

describe Citac::Docker do
  it 'should list docker images' do
    images = Citac::Docker.images
    images.each do |image|
      puts "#{image.id}\t#{image.full_name}"
    end
  end
end