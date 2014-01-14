
# update installation of Ruby using RVM
bash "ruby_rvm_install" do
  # include platform-speficic installation script code
  code node['ruby']['install_script'][node['platform']]
  not_if "ruby -v 2> /dev/null | grep #{node['ruby']['version_short']}"
end

# set rvm environment variables on bash login
bash "ruby_enable_rvm" do
  code <<-EOH
	# add two lines to the beginning (!) of /root/.bashrc
	sed -i '2isource /usr/local/rvm/scripts/rvm' /root/.bashrc
	sed -i '3irvm use ruby-#{node['ruby']['version']}' /root/.bashrc
EOH
  not_if "cat /root/.bashrc | grep \"rvm use ruby\""
end

# install commonly needed gems
bash "ruby_install_gems" do
  code <<-EOH
	# install common gems
	gem install rspec
	gem install rspec -v 1.3.2 # required for, e.g., cassandra installation
EOH
  not_if "gem list | grep rspec"
end

