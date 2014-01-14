# Dependencies for recipe "pxe_dust::default"

# Create Chef data_bags directory, if it does not yet exist (fixes an
# issue where Chef was complaining that /var/chef/data_bags/.. does not exist)
require 'fileutils'
databags_dir = "/var/chef/data_bags/pxe_dust"
FileUtils.mkpath(databags_dir) if !File.directory?(databags_dir)
databag_file = File.join(databags_dir, "default.json")
`echo '{"id":"default"}' > #{databag_file}`