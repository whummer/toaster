
include_attribute "lxc::general"

default["lxc"]["cont"]["use_proxy"] = true
default["lxc"]["cont"]["proxy_ip"] = "192.168.100.2"
default["lxc"]["cont"]["name"] = "lxc1"
default["lxc"]["cont"]["ip_address"] = nil
default["lxc"]["cont"]["root_path"] = "#{node["lxc"]["root_path"]}/#{node["lxc"]["cont"]["name"]}"
default["lxc"]["cont"]["config_file"] = "#{node["lxc"]["cont"]["root_path"]}/config"
default["lxc"]["cont"]["root_fs"] = "#{node["lxc"]["cont"]["root_path"]}/rootfs"

