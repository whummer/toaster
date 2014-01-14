
package "gdisk" do
  action :install
  not_if "which gdisk"
  only_if "test -e #{node["lxc"]["mount"]["dev_disk"]}"
end

package "parted" do
  action :install
  not_if "which partprobe"
  only_if "test -e #{node["lxc"]["mount"]["dev_disk"]}"
end

bash "vol_create_fs" do
  code <<-EOH
	last_usable_sector=#{node["lxc"]["mount"]["last_sector"]}

	# The following command creates a new file system partition on ephemeral disk.
	# This is required when running certain versions of Fedora in Openstack Clouds.
	# usage: sgdisk --new partnum:start:end /dev/vda (0=default)
	if [ "$last_usable_sector" == "" ]; then
		sgdisk --new 0:0 #{node["lxc"]["mount"]["dev_disk"]}
	else
		sgdisk --new 0:0:$last_usable_sector #{node["lxc"]["mount"]["dev_disk"]}
	fi

	# reload partitions in kernel
	partprobe #{node["lxc"]["mount"]["dev_disk"]}

	# create ext3 file system on newly created partition
	mkfs.ext3 #{node["lxc"]["mount"]["dev_partition"]}
EOH
  # make sure we don't get a timeout, because the operations can take quite long
  timeout 2*60*60
  only_if "test -e #{node["lxc"]["mount"]["dev_disk"]}"
  not_if "test -e #{node["lxc"]["mount"]["dev_partition"]}"
  not_if "df | grep #{node["lxc"]["mount"]["dev_disk"]}"
end


bash "vol_mount_fs" do
  code <<-EOH
	mkdir -p /data
	mount #{node["lxc"]["mount"]["dev_partition"]} /data/
EOH
  not_if "ls /data/* > /dev/null 2>&1"
  only_if "test -e #{node["lxc"]["mount"]["dev_disk"]}"
  not_if "df | grep #{node["lxc"]["mount"]["dev_disk"]}"
end

# sometimes the ephemeral storage device /dev/vdb 
# is automatically mounted on /mnt after boot. In 
# this case, simply link from /mnt to /data
bash "vol_link_fs" do
  code <<-EOH
	rm -rf /data
	ln -s /mnt /data
EOH
  not_if "ls /data/* > /dev/null 2>&1"
  only_if "test -e /mnt"
  only_if "df | grep #{node["lxc"]["mount"]["dev_disk"]}" 
end

