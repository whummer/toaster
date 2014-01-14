

# Cookbook Name:: toaster
# Attributes:: default
#
# Author:: Waldemar Hummer
#

default['toaster']['tmp_dir'] = "/tmp/toaster.testing/"
default['toaster']['cookbook_paths'] = [ 
  "/tmp/toaster_assets/cookbooks/"
]

# Specify additional Ruby LOAD_PATH paths
default['toaster']['additional_load_paths'] = []

# Activate this recipe and the testing mechanism?
default['toaster']['testing_mode'] = true

# If a state property is captured for a task, should 
# it be captured for all subsequent tasks as well?
# (which (drastically) increases the database size)
default['toaster']['transfer_state_config'] = false

# Use "ram" (Rational Asset Manager) or "web" (standard Web server) as server type
default['toaster']['server_type'] = "web" 

# MongoDB database settings
default['toaster']['db_type'] = "mongodb"
default['toaster']['mongodb']['host'] = ""
default['toaster']['mongodb']['port'] = 27017
default['toaster']['mongodb']['db'] = "toaster"
default['toaster']['mongodb']['collection'] = "toaster"

# SOME BUG FIXES for Opscode.com recipes:

# some recipes (e.g., openldap::default) fail if node['domain'] is nil
default['domain'] = '' if !node['domain']
