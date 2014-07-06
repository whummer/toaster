
if platform_family?("debian")

  include_recipe "mysql::server"

else

  bash "error_os" do
    code <<-EOH
    echo "ERROR: Currently supported host OSs: Debian/Ubuntu."
    exit 1
EOH
  end

end

