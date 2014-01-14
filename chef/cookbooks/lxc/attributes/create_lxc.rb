
include_attribute "lxc::start_lxc"

# among others, load required attributes:
# - node["lxc"]["use_copy_on_write"]
# - node["lxc"]["host"]["btrfs_img_path"]
include_attribute "lxc::setup_host"

