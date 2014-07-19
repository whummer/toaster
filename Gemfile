source 'https://rubygems.org'

# load gem dependencies from cloud-toaster.gemspec
deps = gemspec :name => 'cloud-toaster'
deps.each do |dep|
	gem dep.name, dep.requirement
end

# some overrides
gem 'activesupport', :require => "active_support"
gem 'activerecord', :require => "active_record"
