# 
# Recipe cakephp::default contains a "require 'mysql'" statement which fails 
# because the mysql gem is not installed by default. Let's do this here...
#

# update packages
execute "apt-get update" do
  ignore_failure true
  action :nothing
end.run_action(:run) if node['platform_family'] == "debian"
# mysql gem requires build-essential
node.set['build_essential']['compiletime'] = true
include_recipe "build-essential"
# mysql gem requires libmysqlclient-dev
package "libmysqlclient-dev" do
  action :nothing
end.run_action(:install) if node['platform_family'] == "debian"
# install mysql gem
chef_gem "mysql"


# Additionally, fix mysql root password (mysql-server uses an 
# empty password by default under Ubuntu)
node.set['mysql']['server_root_password'] = ""