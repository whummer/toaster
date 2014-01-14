#
# This pre-processing recipe fixes some requirements for cube.
# 

# create Chef data_bags directory, if it does not yet exist (fixes an 
# issue where Chef was complaining that /var/chef/data_bags does not exist)
require 'fileutils'
databags_dir = "/var/chef/data_bags"
FileUtils.mkpath(databags_dir) if !File.directory?(databags_dir)