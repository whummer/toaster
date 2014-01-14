
include_attribute "lxc::general"

default["lxc"]["host"]["use_proxy"] = false
default["lxc"]["host"]["btrfs_img_size_MB"] = 35000
default["lxc"]["host"]["btrfs_img_path"] = "/data/btrfs.img"
default["network"]["host"]["wan_device"] = "eth0"
default["network"]["host"]["bridge_device"] = node["network"]["bridge_dev"]

