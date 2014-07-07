
if platform_family?("debian")

  node.set['mysql']['server_root_password'] = "root"
  include_recipe "mysql::server"

  bash 'db_create' do
    code "echo 'create database toaster;' | mysql -u root -p#{node['mysql']['server_root_password']}"
  end

else

  bash "error_os" do
    code <<-EOH
    echo "ERROR: Currently supported host OSs: Debian/Ubuntu."
    exit 1
EOH
  end

end

