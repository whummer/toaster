
default["lxc"]["root_path"] = "/lxc/"
default["lxc"]["use_copy_on_write"] = false
default["lxc"]["mount_volume"] = false
default["lxc"]["store_containers_on_volume"] = false
default["lxc"]["containers_supported"] = true
if !platform_family?("debian", "fedora", "rhel", "suse")
 set["lxc"]["containers_supported"] = false
end
default["lxc"]["use_docker.io"] = true

# if network.manage_networking is true, setup
# private sub-network; if false, leave networking
# defaults managed by docker
default["network"]["manage_networking"] = false
# managed network settings
default["network"]["gateway"] = "192.168.100.2"
default["network"]["ip_pattern"] = "192.168.100.*"
default["network"]["bridge_dev"] = "docker0"

default["path"]["chroot"] = "/usr/sbin/chroot"
