#
# This pre-processing recipe fixes some requirements for wordpress.
# 

# package required for mysql gem
package "mysql devel package" do
  if ["ubuntu","debian"].include?(node[:platform]) 
    package_name "libmysqlclient-dev"
  else
    package_name "mysql-devel"
  end
  action :install
end

# fix mysql root password (mysql-server uses an 
# empty password by default under Ubuntu)
node.set['mysql']['server_root_password'] = ""
