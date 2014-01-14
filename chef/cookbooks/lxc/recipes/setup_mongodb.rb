
if platform_family?("debian")

  bash "mongodb_add_key" do
    code <<-EOH
    mkdir -p /etc/apt/sources.list.d/
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
    echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' > /etc/apt/sources.list.d/mongodb.list
    apt-get update
EOH
    not_if "which mongod"
    not_if "test -f /etc/apt/sources.list.d/mongodb.list"
  end

  apt_package "mongodb-10gen" do
    action :install
    not_if "which mongod"
  end

  bash "mongodb_start_service" do
    code <<-EOH
    service mongodb restart
EOH
  end

elsif platform_family?("fedora") || platform_family?("linux")

  bash "error_os" do
    code <<-EOH
    echo "ERROR: Currently supported OSs: Debian/Ubuntu."
    exit 1
EOH
  end

end

