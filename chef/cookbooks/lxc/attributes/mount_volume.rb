
include_attribute "lxc::general"

#default["lxc"]["mount"]["dev_disk"] = "/dev/vda"
#default["lxc"]["mount"]["dev_partition"] = "/dev/vda3"
default["lxc"]["mount"]["last_sector"] = "125829086"

default["lxc"]["mount"]["dev_disk"] = "/dev/vdb"
default["lxc"]["mount"]["dev_partition"] = "/dev/vdb1"
default["lxc"]["mount"]["last_sector"] = "" # leave blank for auto-detection

