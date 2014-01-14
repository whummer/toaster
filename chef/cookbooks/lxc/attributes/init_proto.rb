
include_attribute "lxc::general"
include_attribute "lxc::init_bare_os"
include_attribute "lxc::setup_host"
include_attribute "lxc::start_lxc"
include_attribute "lxc::install_ruby"

default["lxc"]["proto"]["name"] = "prototype_ubuntu1"
default["lxc"]["proto"]["root_path"] = "#{node["lxc"]["root_path"]}/#{node["lxc"]["proto"]["name"]}"
default["lxc"]["proto"]["root_fs"] = "#{node["lxc"]["proto"]["root_path"]}/rootfs/"
default["lxc"]["proto"]["config_file"] = "#{node["lxc"]["proto"]["root_path"]}/config"

default["lxc"]["proto"]["root_pass"] = "passw0rd"

default["lxc"]["proto"]["network_type"] = "veth"
default["lxc"]["proto"]["network_link"] = node["network"]["bridge_dev"]
default["lxc"]["proto"]["ip_address"] = "192.168.100.250"
default["lxc"]["proto"]["ssh_user"] = "root"
