# Dependencies for recipe "gitosis::default"

# Create Chef data_bags directory, if it does not yet exist (fixes an
# issue where Chef was complaining that /var/chef/data_bags does not exist)
require 'fileutils'
databags_dir = "/var/chef/data_bags"
FileUtils.mkpath(databags_dir) if !File.directory?(databags_dir)

# Create user/group gitosis (recipe fails if they don't exist)
user "gitosis" do
  action :create
end
group "gitosis" do
  action :create
  members "gitosis"
  append false
end