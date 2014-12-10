
if node["lxc"]["mount_volume"]
  # if we are on an Openstack host, mount volume and create file system..
  include_recipe "lxc::mount_volume"
else
  # else, dont create the file system, but create the /data/ directory
  bash "host_link_datadir" do
    code <<-EOH
    rm -rf /data
    ln -s /mnt /data
  EOH
    not_if "ls /data/* > /dev/null 2>&1"
    only_if "test -e /mnt"
  end
  bash "host_create_datadir" do
    code <<-EOH
    mkdir -p /data
  EOH
    not_if "test -e /data"
  end
end

bash "host_mount_cgroup" do
  code <<-EOH
	# mount control group filesystem
	mkdir -p /cgroup
	mount none -t cgroup /cgroup 2> /dev/null
	exit 0
EOH
  not_if "(test -d /cgroup) && (df | grep '/cgroup')"
end

if platform_family?("debian")
  apt_package "btrfs-tools" do
    action :install
    not_if "which btrfs"
    only_if do node["lxc"]["host"]["use_copy_on_write"] end
  end
  apt_package "host" do
    action :install
    not_if "which host"
    ignore_failure true
  end
  apt_package "openjdk-7-jdk" do
    action :install
    not_if "which javac"
    ignore_failure true
    only_if 'apt-cache search openjdk-7-jdk | grep ""'
  end
  # fallback to java 6 if java 7 is not available
  apt_package "openjdk-6-jdk" do
    action :install
    not_if "which javac"
    ignore_failure true
  end
elsif platform_family?("fedora") || platform_family?("linux")
  yum_package "btrfs-progs" do
    action :install
    not_if "which btrfs"
    only_if do node["lxc"]["host"]["use_copy_on_write"] end
  end
  yum_package "bind-utils" do
    action :install
    not_if "which host"
  end
  yum_package "java-1.7.0-openjdk" do
    action :install
    not_if "which javac"
  end
end


bash "host_create_btrfs_image" do
  code <<-EOH
	echo "INFO: Creating image file for btrfs filesystem under #{node["lxc"]["host"]["btrfs_img_path"]}"

	# make sure the parent directory for the image file exists
	mkdir -p #{node["lxc"]["host"]["btrfs_img_path"]}
	rm -rf #{node["lxc"]["host"]["btrfs_img_path"]}

	# create image file
	dd if=/dev/zero of=#{node["lxc"]["host"]["btrfs_img_path"]} bs=1MB count=#{node["lxc"]["host"]["btrfs_img_size_MB"]}
	mkfs.btrfs #{node["lxc"]["host"]["btrfs_img_path"]}
EOH
  not_if "test -f #{node["lxc"]["host"]["btrfs_img_path"]}"
  only_if do node["lxc"]["host"]["use_copy_on_write"] end
end

bash "host_config_btrfs" do
  code <<-EOH
	mkdir -p /mnt/btrfs
	mount -t btrfs -o loop #{node["lxc"]["host"]["btrfs_img_path"]} /mnt/btrfs
	if [ ! -e #{node["lxc"]["root_path"]} ]; then
		ln -s /mnt/btrfs #{node["lxc"]["root_path"]}
	fi
EOH
  only_if do node["lxc"]["host"]["use_copy_on_write"] end
  not_if "df | grep /mnt/btrfs"
end

bash "host_install_lxc" do
  code <<-EOH
  echo 'node["lxc"]["containers_supported"]=#{node["lxc"]["containers_supported"]}'
	# install requirements for lxc and some tools
	yum install --skip-broken -y libcap-devel febootstrap bridge-utils libvirt git screen
	# install lxc
	yum install --skip-broken -y lxc
	# fix for https://bugs.archlinux.org/task/31211
	mount --make-rprivate /
EOH
  not_if "which lxc-ls 2> /dev/null"
  only_if do node["lxc"]["containers_supported"] end
  # don't execute if we use docker.io tools
  not_if do node["lxc"]["use_docker.io"] end
end

# configure SSH settings to disable strict host checking when connecting to LXC containers
node.set["ssh"]["permit_subnet_pattern"] = node["network"]["ip_pattern"]
if node["lxc"]["containers_supported"]
	include_recipe "ssh::permit_subnet"
end

# install docker.io tools for LXC handling
if node["lxc"]["containers_supported"] && node["lxc"]["use_docker.io"]
	include_recipe "lxc::install_docker"
end

# configure network bridge on host
bash "host_create_bridge" do
  code <<-EOH
	/usr/sbin/brctl addbr #{node["network"]["host"]["bridge_device"]}
	/usr/sbin/brctl setfd #{node["network"]["host"]["bridge_device"]} 0
EOH
  not_if "/sbin/iptables | grep #{node["network"]["host"]["bridge_device"]}"
  only_if do node["lxc"]["containers_supported"] end
  # don't execute if we use docker.io tools
  not_if do node["lxc"]["use_docker.io"] end
end

# configure network bridge on host
bash "host_config_bridge" do
  code <<-EOH
	/sbin/ifconfig #{node["network"]["host"]["bridge_device"]} #{node["network"]["gateway"]} netmask 255.255.0.0 promisc up
EOH
  only_if do node["lxc"]["containers_supported"] end
  only_if do node["network"]["manage_networking"] end
  not_if "/sbin/iptables | grep #{node["network"]["host"]["bridge_device"]}"
end

bash "host_setup_bridge_iptables" do
  code <<-EOH
	/sbin/iptables -t nat -A POSTROUTING -o #{node["network"]["host"]["wan_device"]} -j MASQUERADE
	echo 1 > /proc/sys/net/ipv4/ip_forward
EOH
  only_if do node["lxc"]["containers_supported"] end
  not_if "/sbin/iptables -t nat -L POSTROUTING | grep MASQUERADE | grep anywhere"
end

# disable iptables if packet rejection is turned on
bash "host_disable_iptables_reject" do
  code <<-EOH
	/sbin/service iptables stop
EOH
  only_if do node["lxc"]["containers_supported"] end
  only_if "iptables -L | grep 'reject-with icmp-host-prohibited'"
end


# setup squid proxy on host
if node["lxc"]["containers_supported"]
  include_recipe "lxc::setup_proxy"
end

# setup DB server on host
include_recipe "lxc::setup_database"

# required gem for adding encoding headers to avoid "invalid multibyte char" errors
gem_package "magic_encoding" do
  action :install
  ignore_failure true
end

