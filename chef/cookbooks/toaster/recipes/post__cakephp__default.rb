#
# server_aliases has to be an array (and not a string, as below), 
# otherwise the Apache2 config file templating fails.
#

app = web_app "cakephp" do
  template "cakephp.conf.erb"
  docroot "#{node[:cakephp][:dir]}/app/webroot"
  server_name server_fqdn
  # original:
  #server_aliases node.fqdn
  # fixed:
  server_aliases [node.fqdn]
end

# this is required, otherwise Chef fills in the wrong cookbook/recipe name
app.cookbook_name = "cakephp"
app.recipe_name = "default"

# Fix mysql command for use with empty password.
execute "mysql-install-cakephp-privileges" do
  # original:
  #command "/usr/bin/mysql -u root -p#{node[:mysql][:server_root_password]} < /etc/mysql/cakephp-grants.sql"
  # fixed:
  command "/usr/bin/mysql -u root #{node['mysql']['server_root_password'].empty? ? '' : '-p' }#{node[:mysql][:server_root_password]} < /etc/mysql/cakephp-grants.sql"
  action :nothing
end
