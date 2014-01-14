# This pre-processing recipe fixes requirements for munin::server.

# Chef complains if /var/chef/data_bags does not exist
require 'fileutils'
databags_dir = "/var/chef/data_bags"
FileUtils.mkpath(databags_dir) if !File.directory?(databags_dir)