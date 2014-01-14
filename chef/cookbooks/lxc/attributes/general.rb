
default["lxc"]["root_path"] = "/lxc/"
default["lxc"]["use_copy_on_write"] = false
default["lxc"]["mount_volume"] = false
default["lxc"]["store_containers_on_volume"] = false
default["lxc"]["use_docker.io"] = true
if !platform_family?("debian")
	set["lxc"]["use_docker.io"] = false
end

default["network"]["gateway"] = "192.168.100.2"
default["network"]["ip_pattern"] = "192.168.100.*"
default["network"]["bridge_dev"] = "docker0"

default["path"]["chroot"] = "/usr/sbin/chroot"
