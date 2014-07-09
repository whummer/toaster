
if platform_family?("debian")

  node.set['mysql']['server_root_password'] = "root"
  include_recipe "mysql::server"

  root_dir = File.join(File.dirname(__FILE__), "..","..","..","..")

  bash 'db_create' do
    code <<-EOH
    echo 'create database toaster;' | mysql -u root -p#{node['mysql']['server_root_password']}
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
