# Dependencies for recipe "pxe_dust::default"

# Create Chef data_bags directory, if it does not yet exist (fixes an
# issue where Chef was complaining that /var/chef/data_bags/.. does not exist)
require 'fileutils'
databags_dir = "/var/chef/data_bags/sensu"
FileUtils.mkpath(databags_dir) if !File.directory?(databags_dir)
databag_file = File.join(databags_dir, "ssl.json")
`echo '{"id":"ssl"}' > #{databag_file}`