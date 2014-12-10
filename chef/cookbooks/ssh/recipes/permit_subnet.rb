#
# Cookbook Name:: ssh
# Recipe:: permit_subnet
#
# Author:: Waldemar Hummer
# 
# Configure SSH settings to disable strict host checking when connecting to LXC containers
#

include_recipe "ssh::default"

ruby_block "ssh_permit_subnet" do
  block do
  `mkdir -p /root/.ssh`
  cfg_dir = node['ssh']['config_dir']
  cfg_file = "#{cfg_dir}/config"
  `echo "Host #{node["ssh"]["permit_subnet_pattern"]}" >> #{cfg_file}`
  `echo '  UserKnownHostsFile=/dev/null' >> #{cfg_file}`
  `echo '  StrictHostKeyChecking=no' >> #{cfg_file}`
  `echo '  ConnectionAttempts=10' >> #{cfg_file}`
  end
  not_if do `cat #{node['ssh']['config_dir']}/config | grep \"#{node["ssh"]["permit_subnet_pattern"]}\"`; $? == 0 end
end
