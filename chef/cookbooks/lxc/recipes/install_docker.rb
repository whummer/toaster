
if platform_family?("debian")

  bash "add_kernel_repo" do
    code <<-EOH
    add-apt-repository ppa:canonical-kernel-team/ppa 
    apt-get update
EOH
    not_if "which docker"
  end

  pkg_name = "linux-image-extra-#{`uname -r`}".strip
  apt_package pkg_name do
    action :install
    not_if "which docker"
  end

  bash "install_docker_prepare" do
    code <<-EOH
	curl https://get.docker.io | sh -x
EOH
    not_if "which docker"
  end

  bash "start_docker_daemon" do
    code <<-EOH
    docker -d &
EOH
    not_if "ps aux | grep 'docker -d' | grep -v grep"
  end

  bash "install_docker_init" do
    code <<-EOH
	docker pull ubuntu
EOH
  end

  bash "host_docker_link" do
    code <<-EOH
	mv /var/lib/docker /mnt
	rm -rf /var/lib/docker
	ln -s /mnt/docker /var/lib/docker
EOH
    only_if do node["lxc"]["store_containers_on_volume"] end
    only_if "test -d /mnt"
    not_if "test -d /mnt/docker"
    # don't execute if we use docker.io tools
    only_if do node["lxc"]["use_docker.io"] end
  end

elsif platform_family?("fedora") || platform_family?("linux")

  bash "error_os" do
    code <<-EOH
    echo "ERROR: Currently supported OSs: Debian/Ubuntu."
    exit 1
EOH
  end

end

