
include_attribute "lxc::general"

default["lxc"]["bare_os"]["distribution"] = "ubuntu"
if node["lxc"]["bare_os"]["distribution"] == "ubuntu"
	default["lxc"]["bare_os"]["release"] = "quantal"
elsif node["lxc"]["bare_os"]["distribution"] == "fedora"
	default["lxc"]["bare_os"]["release"] = "16"
end
default["lxc"]["bare_os"]["arch"] = "amd64"
default["lxc"]["bare_os"]["cachedir"] = "/var/cache/lxc/" +
                                          "#{node["lxc"]["bare_os"]["distribution"]}/" +
                                          "#{node["lxc"]["bare_os"]["arch"]}/" +
                                          "#{node["lxc"]["bare_os"]["release"]}"

