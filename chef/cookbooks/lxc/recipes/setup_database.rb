
if platform_family?("debian")

  root_dir = File.join(File.dirname(__FILE__), "..","..","..","..")
  $LOAD_PATH << File.join(root_dir, "lib")

  cfg_db_pass = Toaster::Config.get("db.password")
  cfg_db_pass = "root" if "#{cfg_db_pass}".empty?
  node.set['mysql']['server_root_password'] = cfg_db_pass
  include_recipe "mysql::server"

  bash 'db_create' do
    code <<-EOH
    echo 'create database toaster;' | mysql -u root -p#{node['mysql']['server_root_password']}
    # TODO: GRANT ALL for user "root" on 192.168.100.2 - do we need to add this??
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
