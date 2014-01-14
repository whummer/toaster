
# check if copy-on-write (btrfs) configuration is up-to-date.
# (required, e.g., if the host machine has rebooted)
if node["lxc"]["use_copy_on_write"]
	if !File.exist?(node["lxc"]["host"]["btrfs_img_path"])
		include_recipe "lxc::setup_host"
	end
end

bash "lxc_check_existence" do
  code <<-EOH
	echo "LXC configuration '/lxc/#{node["lxc"]["cont"]["name"]}/config' already exists."
	echo "Please provide a different container name or use recipe lxc::start_lxc"
	exit 1
EOH
  only_if "test -f /lxc/#{node["lxc"]["cont"]["name"]}/config"
end

bash "lxc_prepare_rootdir" do
	if node["lxc"]["use_copy_on_write"]
  code <<-EOH
	name=#{node["lxc"]["cont"]["name"]}
	prototype_name=#{node["lxc"]["proto"]["name"]}
	rm -rf /lxc/$name
	/sbin/btrfs subvolume snapshot /lxc/$prototype_name /lxc/$name
EOH
	else
  code <<-EOH
	name=#{node["lxc"]["cont"]["name"]}
	prototype_name=#{node["lxc"]["proto"]["name"]}
	mkdir -p /lxc/$name
  cp /lxc/$prototype_name/config /lxc/$name/config
EOH
	end
end

bash "lxc_copy_rootfs" do
	if !node["lxc"]["use_copy_on_write"]
  code <<-EOH
	name=#{node["lxc"]["cont"]["name"]}
	prototype_name=#{node["lxc"]["proto"]["name"]}
	echo "INFO: Copying container root directory from /lxc/$prototype_name to /lxc/$name"
	cp -r /lxc/$prototype_name/* /lxc/$name/
EOH
	end
  # don't execute if we use docker.io tools
  not_if do node["lxc"]["use_docker.io"] end
end

bash "lxc_adjust_config" do
  code <<-EOH
	name=#{node["lxc"]["cont"]["name"]}
	prototype_name=#{node["lxc"]["proto"]["name"]}

	# adjust values in config files
	sed -i "s|lxc.utsname = $prototype_name|lxc.utsname = $name|g" /lxc/$name/config
	sed -i "s|lxc.rootfs = /lxc/[/]*$prototype_name/[/]*rootfs|lxc.rootfs = /lxc/$name/rootfs|g" /lxc/$name/config
	sed -i "s|lxc.mount = /lxc/[/]*$prototype_name/[/]*fstab|lxc.mount = /lxc/$name/fstab|g" /lxc/$name/config
	sed -i "s|lxc.network.ipv4 = .*\\$|lxc.network.ipv4 = #{node["lxc"]["cont"]["ip_address"]}|g" /lxc/$name/config
	if [ -f /lxc/$name/fstab ]; then
		sed -i "s|/lxc/[/]*$prototype_name/|/lxc/$name/|g" /lxc/$name/fstab
	fi

	# create a file which contains the container's prototype name
	echo "$prototype_name" > /lxc/$name/container.prototype.name
EOH
end

bash "lxc_fix_network_config" do
  code <<-EOH
	name=#{node["lxc"]["cont"]["name"]}

	# turn /etc/resolv.conf symlink to an actual file
	cp /lxc/$name/rootfs/etc/resolv.conf /lxc/$name/rootfs/etc/resolv.conf.bak
	rm /lxc/$name/rootfs/etc/resolv.conf
	cp /lxc/$name/rootfs/etc/resolv.conf.bak /lxc/$name/rootfs/etc/resolv.conf

	# fix hostname files
	echo "$name" > /lxc/$name/rootfs/etc/hostname
	echo "127.0.0.1 $name $name" > /lxc/$name/rootfs/etc/hosts

EOH
  # don't execute if we use docker.io tools
  not_if do node["lxc"]["use_docker.io"] end
end

# start the newly created LXC container
include_recipe "lxc::start_lxc"

bash "lxc_fix_started_container" do
  code <<-EOH
	name=#{node["lxc"]["cont"]["name"]}

	# make /tmp directory writable to everyone
	chmod 777 /lxc/$name/rootfs/tmp
EOH
end

ruby_block "lxc_welcome_message" do
  block do
	puts "INFO: SSH into the instance using root@""#{node["lxc"]["cont"]["ip_address"]}"
  end
end
