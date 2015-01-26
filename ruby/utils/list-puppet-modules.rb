require 'json'
require 'rest_client'

require_relative '../lib/citac/puppet/forge/client'

query = Citac::Puppet::Forge::PuppetForgeModuleQuery.new
query.os = 'ubuntu'

count = 0
Citac::Puppet::Forge::PuppetForgeClient.new.each_module query do |mod|
  puts "#{mod.full_name}\t#{mod.downloads} downloads\t#{mod.versions.length} versions"
  count += 1
end

puts
puts "#{count} modules found"