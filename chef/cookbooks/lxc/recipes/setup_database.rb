
root_dir = File.join(File.dirname(__FILE__), "..","..","..","..")
$LOAD_PATH << File.join(root_dir, "lib")
require 'toaster/util/config'

cfg_db_pass = Toaster::Config.get("db.password")
node.set['mysql']['server_root_password'] = cfg_db_pass

if platform_family?("debian")

  # recipe mysql::server requires a DB password
  cfg_db_pass = "root" if "#{cfg_db_pass}".empty?
  node.set['mysql']['server_root_password'] = cfg_db_pass
  include_recipe "mysql::server"

end

bash "error_no_mysql" do
  code <<-EOH
  echo "ERROR: MySQL server not installed. Please install manually, configure username/password in config.json, then re-run this recipe."
    exit 1
EOH
  not_if "which mysql"
end

db_pass_param = "#{node['mysql']['server_root_password']}".empty? ? "" : "-p#{node['mysql']['server_root_password']}"

bash 'db_create' do
  code <<-EOH
  db_pass=#{node['mysql']['server_root_password']}
  ip_pattern=#{node["network"]["ip_pattern"].gsub('*','%')}
  echo 'create database toaster;' | mysql -u root #{db_pass_param}
  echo "GRANT ALL ON toaster.* TO 'root'@'$ip_pattern' IDENTIFIED BY '$db_pass';" | mysql -u root #{db_pass_param}
  echo "FLUSH PRIVILEGES;" | mysql -u root #{db_pass_param}
EOH
  only_if "which mysql"
  not_if "echo \"show databases;\" | mysql -u root #{db_pass_param} | grep toaster"
end
  
bash 'db_create_tables' do
  code <<-EOH
  cd #{root_dir}/webapp && ./bin/rake db:migrate RAILS_ENV=development
EOH
  only_if "which mysql"
  not_if "echo \"use toaster; show tables;\" | mysql -u root #{db_pass_param} | grep user"
end
