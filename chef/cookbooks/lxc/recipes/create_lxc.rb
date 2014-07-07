
# check if copy-on-write (btrfs) configuration is up-to-date.
# (required, e.g., if the host machine has rebooted)
if node["lxc"]["use_copy_on_write"]
	if !File.exist?(node["lxc"]["host"]["btrfs_img_path"])
		include_recipe "lxc::setup_host"
	end
end

bash "lxc_check_existence" do
  code <<-EOH
	echo "LXC configuration '#{node["lxc"]["root_path"]}/#{node["lxc"]["cont"]["name"]}/config' already exists."
	echo "Please provide a different container name or use recipe lxc::start_lxc"
	exit 1
EOH
  only_if "test -f #{node["lxc"]["root_path"]}/#{node["lxc"]["cont"]["name"]}/config"
end

bash "lxc_prepare_rootdir" do
	if node["lxc"]["use_copy_on_write"]
  code <<-EOH
	name=#{node["lxc"]["cont"]["name"]}
	prototype_name=#{node["lxc"]["proto"]["name"]}
	rm -rf #{node["lxc"]["root_path"]}/$name
	/sbin/btrfs subvolume snapshot #{node["lxc"]["root_path"]}/$prototype_name #{node["lxc"]["root_path"]}/$name
EOH
	else
  code <<-EOH
	name=#{node["lxc"]["cont"]["name"]}
	prototype_name=#{node["lxc"]["proto"]["name"]}
	mkdir -p #{node["lxc"]["root_path"]}/$name
  cp #{node["lxc"]["root_path"]}/$prototype_name/config #{node["lxc"]["root_path"]}/$name/config
EOH
	end
end

bash "lxc_copy_rootfs" do
	if !node["lxc"]["use_copy_on_write"]
  code <<-EOH
	name=#{node["lxc"]["cont"]["name"]}
	prototype_name=#{node["lxc"]["proto"]["name"]}
	root_path=#{node["lxc"]["root_path"]}
	echo "INFO: Copying container root directory from $root_path/$prototype_name to $root_path/$name"
	cp -r $root_path/$prototype_name/* $root_path/$name/
EOH
	end
  # don't execute if we use docker.io tools
  not_if do node["lxc"]["use_docker.io"] end
end

bash "lxc_adjust_config" do
  code <<-EOH
	name=#{node["lxc"]["cont"]["name"]}
	prototype_name=#{node["lxc"]["proto"]["name"]}
	root_path=#{node["lxc"]["root_path"]}

	# adjust values in config files
	sed -i "s|lxc.utsname = $prototype_name|lxc.utsname = $name|g" $root_path/$name/config
	sed -i "s|lxc.rootfs = $root_path/[/]*$prototype_name/[/]*rootfs|lxc.rootfs = $root_path/$name/rootfs|g" $root_path/$name/config
	sed -i "s|lxc.mount = $root_path/[/]*$prototype_name/[/]*fstab|lxc.mount = $root_path/$name/fstab|g" $root_path/$name/config
	sed -i "s|lxc.network.ipv4 = .*\\$|lxc.network.ipv4 = #{node["lxc"]["cont"]["ip_address"]}|g" $root_path/$name/config
	if [ -f $root_path/$name/fstab ]; then
		sed -i "s|$root_path/[/]*$prototype_name/|$root_path/$name/|g" $root_path/$name/fstab
	fi

	# create a file which contains the container's prototype name
	echo "$prototype_name" > #{node["lxc"]["root_path"]}/$name/container.prototype.name
EOH
end

bash "lxc_fix_network_config" do
  code <<-EOH
	name=#{node["lxc"]["cont"]["name"]}
	root_path=#{node["lxc"]["root_path"]}

	# turn /etc/resolv.conf symlink to an actual file
	cp $root_path/$name/rootfs/etc/resolv.conf $root_path/$name/rootfs/etc/resolv.conf.bak
	rm $root_path/$name/rootfs/etc/resolv.conf
	cp $root_path/$name/rootfs/etc/resolv.conf.bak $root_path/$name/rootfs/etc/resolv.conf

	# fix hostname files
	echo "$name" > #{node["lxc"]["root_path"]}/$name/rootfs/etc/hostname
	echo "127.0.0.1 $name $name" > #{node["lxc"]["root_path"]}/$name/rootfs/etc/hosts

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
	chmod 777 #{node["lxc"]["root_path"]}/$name/rootfs/tmp
EOH
end

ruby_block "lxc_welcome_message" do
  block do
	puts "INFO: SSH into the instance using root@""#{node["lxc"]["cont"]["ip_address"]}"
  end
end
