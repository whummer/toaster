
if platform_family?("debian")

  root_dir = File.join(File.dirname(__FILE__), "..","..","..","..")
  $LOAD_PATH << File.join(root_dir, "lib")
  require 'toaster/util/config'

  cfg_db_pass = Toaster::Config.get("db.password")
  cfg_db_pass = "root" if "#{cfg_db_pass}".empty?
  node.set['mysql']['server_root_password'] = cfg_db_pass
  include_recipe "mysql::server"

  bash 'db_create' do
    code <<-EOH
    db_pass=#{node['mysql']['server_root_password']}
    ip_pattern=#{node["network"]["ip_pattern"].gsub('*','%')}
    echo 'create database toaster;' | mysql -u root -p$db_pass
    echo "GRANT ALL ON toaster.* TO 'root'@'$ip_pattern' IDENTIFIED BY '$db_pass';" | mysql -u root -p$db_pass
    echo "FLUSH PRIVILEGES;" | mysql -u root -p$db_pass
    cd #{root_dir}/webapp && ./bin/rake db:migrate RAILS_ENV=development
EOH
    not_if "echo \"show databases;\" | mysql -u root -p#{node['mysql']['server_root_password']} | grep toaster"
  end

else

  bash "error_os" do
    code <<-EOH
    echo "ERROR: Currently supported host OSs: Debian/Ubuntu."
    exit 1
EOH
  end

end
