
include_recipe "lxc::init_bare_os"

rootfs = node["lxc"]["proto"]["root_fs"]
chroot_cmd = "#{node["path"]["chroot"]} #{rootfs}"
lxc_config = "#{node["lxc"]["proto"]["config_file"]}"
cache="#{node["lxc"]["bare_os"]["cachedir"]}"

# include code in Ruby LOAD_PATH
code_dir = File.join(File.dirname(__FILE__), "..","..","..","..", "lib")
$:.unshift(code_dir)
require 'toaster/util/config'

package "proto_install_btrfs" do
  if ["ubuntu","debian"].include?(node[:platform]) 
    package_name "btrfs-tools"
  else
    package_name "btrfs-progs"
  end
  action :install
  only_if do node["lxc"]["use_copy_on_write"] end
  not_if "which btrfs"
end

bash "proto_init_cow" do
  code <<-EOH
	btrfs subvolume create #{node["lxc"]["root_path"]}/#{node["lxc"]["proto"]["name"]}
EOH
  only_if do node["lxc"]["use_copy_on_write"] end
  not_if "test -f #{node["lxc"]["root_path"]}/#{node["lxc"]["proto"]["name"]}"
end

bash "proto_copy_os" do
  code <<-EOH
	# check if we want to use copy-on-write (btrfs)
	if [ -d /mnt/btrfs/ ]; then
		echo "INFO: Creating new btrfs subvolume at '/mnt/btrfs/#{node["lxc"]["proto"]["name"]}'"
		btrfs subvolume create /mnt/btrfs/#{node["lxc"]["proto"]["name"]}
	fi

	echo -n "INFO: Copying rootfs from '#{cache}/rootfs/' to '#{rootfs}' ..."
	mkdir -p #{rootfs}
	rsync -a #{cache}/rootfs/ #{rootfs}
EOH
  not_if "test -d #{rootfs}"
  # don't execute if we use docker.io tools
  not_if do node["lxc"]["use_docker.io"] end
end

bash "proto_config_os" do
  code <<-EOH

    # disable selinux
    mkdir -p #{rootfs}/selinux
    echo 0 > #{rootfs}/selinux/enforce

    # copy /etc/resolv.conf from host file system to container file system
    cp /etc/resolv.conf #{rootfs}/etc/resolv.conf

    # set the hostname
    cat <<EOF > #{rootfs}/etc/hostname
#{node["lxc"]["proto"]["name"]}
EOF

    # set minimal hosts
    cat <<EOF > #{rootfs}/etc/hosts
127.0.0.1 localhost
EOF

    cat <<EOF > #{rootfs}/etc/init/devpts.conf
# this should fix problems with TTY when trying to ssh into container
start on startup
exec mount -t devpts none /dev/pts -o rw,noexec,nosuid,gid=5,mode=0620
EOF

    dev_path="#{rootfs}/dev"
    rm -rf $dev_path
    mkdir -p $dev_path
    mknod -m 666 ${dev_path}/null c 1 3
    mknod -m 666 ${dev_path}/zero c 1 5
    mknod -m 666 ${dev_path}/random c 1 8
    mknod -m 666 ${dev_path}/urandom c 1 9
    mkdir -m 755 ${dev_path}/pts
    mkdir -m 1777 ${dev_path}/shm
    mknod -m 666 ${dev_path}/tty c 5 0
    mknod -m 666 ${dev_path}/tty0 c 4 0
    mknod -m 666 ${dev_path}/tty1 c 4 1
    mknod -m 666 ${dev_path}/tty2 c 4 2
    mknod -m 666 ${dev_path}/tty3 c 4 3
    mknod -m 666 ${dev_path}/tty4 c 4 4
    mknod -m 666 ${dev_path}/tty5 c 4 5
    mknod -m 666 ${dev_path}/tty6 c 4 6
    mknod -m 666 ${dev_path}/tty7 c 4 7
    mknod -m 600 ${dev_path}/console c 5 1
    mknod -m 666 ${dev_path}/full c 1 7
    mknod -m 600 ${dev_path}/initctl p
    mknod -m 666 ${dev_path}/ptmx c 5 2

    # on some releases, /etc/rc.local ends with a line "exit 0", which we need to get rid of first...
    sed -i "s/^exit 0//gi" #{rootfs}/etc/rc.local

    echo "ifconfig > /tmp/ifconfig.rc.local.out" >> #{rootfs}/etc/rc.local
    echo "echo \\"#!/bin/bash\\" > /tmp/ping.rc.local.sh" >> #{rootfs}/etc/rc.local
    echo "echo \\"sleep 1\\" >> /tmp/ping.rc.local.sh" >> #{rootfs}/etc/rc.local
    echo "echo \\"ping -c 1 #{node["network"]["gateway"]} 2>&1 >> /tmp/ping.rc.local.out\\" >> /tmp/ping.rc.local.sh" >> #{rootfs}/etc/rc.local
    echo "echo \\"route add default gw #{node["network"]["gateway"]}\\" >> /tmp/ping.rc.local.sh" >> #{rootfs}/etc/rc.local
    echo "exit 0" >> #{rootfs}/etc/rc.local

    echo "INFO: setting root passwd to '#{node["lxc"]["proto"]["root_pass"]}'"
    echo "root:#{node["lxc"]["proto"]["root_pass"]}" | #{chroot_cmd} chpasswd

EOH
  not_if "cat #{rootfs}/etc/hostname | grep #{node["lxc"]["proto"]["name"]}"
  # don't execute if we use docker.io tools
  not_if do node["lxc"]["use_docker.io"] end
end


bash "proto_write_lxc_config" do
  code <<-EOH
    mkdir -p #{node["lxc"]["proto"]["root_path"]}
    cat <<EOF >> #{node["lxc"]["proto"]["root_path"]}/config
lxc.utsname = #{node["lxc"]["proto"]["name"]}
lxc.tty = 1
lxc.pts = 1024
lxc.console = none
#lxc.arch = $arch_lxc # not supported yet
lxc.rootfs = #{rootfs}
lxc.mount = #{node["lxc"]["proto"]["root_path"]}/fstab
#networking
lxc.network.type = #{node["lxc"]["proto"]["network_type"]}
lxc.network.flags = up
lxc.network.link = #{node["lxc"]["proto"]["network_link"]}
lxc.network.name = eth0
lxc.network.ipv4 = #{node["lxc"]["proto"]["ip_address"]}/24
lxc.network.hwaddr = 00:24:1d:2f:e5:5f
lxc.network.mtu = 1500
#cgroups
lxc.cgroup.devices.deny = a
# /dev/null and zero
lxc.cgroup.devices.allow = c 1:3 rwm
lxc.cgroup.devices.allow = c 1:5 rwm
# consoles
lxc.cgroup.devices.allow = c 5:1 rwm
lxc.cgroup.devices.allow = c 5:0 rwm
lxc.cgroup.devices.allow = c 4:0 rwm
lxc.cgroup.devices.allow = c 4:1 rwm
# /dev/{,u}random
lxc.cgroup.devices.allow = c 1:9 rwm
lxc.cgroup.devices.allow = c 1:8 rwm
lxc.cgroup.devices.allow = c 136:* rwm
lxc.cgroup.devices.allow = c 5:2 rwm
# rtc
lxc.cgroup.devices.allow = c 254:0 rwm
EOF

    cat <<EOF > #{node["lxc"]["proto"]["root_path"]}/fstab
proc            #{rootfs}/proc         proc    nodev,noexec,nosuid 0 0
devpts          #{rootfs}/dev/pts      devpts defaults 0 0
sysfs           #{rootfs}/sys          sysfs defaults  0 0
EOF
EOH
  not_if "test -f #{node["lxc"]["proto"]["root_path"]}/config"
  # don't execute if we use docker.io tools
  not_if do node["lxc"]["use_docker.io"] end
end

bash "proto_docker_create" do
  if node["lxc"]["bare_os"]["distribution"] == "ubuntu"
    code <<-EOH
	proto_name=#{node["lxc"]["proto"]["name"]}
  root_path=#{node["lxc"]["root_path"]}

	mkdir -p #{node["lxc"]["proto"]["root_path"]}
	cat <<EOF > #{node["lxc"]["proto"]["root_path"]}/Dockerfile
	FROM ubuntu
	RUN mkdir -p /var/run/sshd
  # add ssh dir
  RUN mkdir -p /root/.ssh
EOF
	proto_name=#{node["lxc"]["proto"]["name"]}
	mkdir -p #{node["lxc"]["root_path"]}/$proto_name/dockerfiles/.ssh/
	if [ ! -f $HOME/.ssh/id_rsa.pub ]; then
    ssh-keygen -f $HOME/.ssh/id_rsa.pub -P ""
	fi
	cp $HOME/.ssh/id_rsa.pub #{node["lxc"]["root_path"]}/$proto_name/dockerfiles/.ssh/authorized_keys
	imgID=`docker build -t prototypes:$proto_name #{node["lxc"]["proto"]["root_path"]} | grep "Successfully built" | tail -n 1 | sed "s/Successfully built //g"`
	echo "INFO: new docker image ID: '$imgID'"
	if [ "$imgID" == "" ]; then
		echo "WARN: Docker image creation unsuccessful..."
		docker build #{node["lxc"]["proto"]["root_path"]}
		exit 1
	fi
	echo "$imgID" > #{node["lxc"]["root_path"]}/$proto_name/docker.image.id

  manage_networking=#{node["network"]["manage_networking"] ? 1 : 0}
  if [ $manage_networking == 1 ]; then
    network_setup="ip addr flush dev eth0; ip addr add #{node["lxc"]["proto"]["ip_address"]}/24 dev eth0; ip route del default; ip route add default via #{node["network"]["gateway"]};"
  else
    network_setup="" #noop
  fi

  cidfile=$root_path/$proto_name/docker.container.id
  rm -f $cidfile
  # the commands in $network_setup can only be run in "privileged" docker mode:
	docker run --privileged --cidfile=$cidfile $imgID bash -c "$network_setup apt-get update; apt-get install -y net-tools openssh-server iptables dnsutils iputils-ping vim; update-rc.d ssh defaults"
EOH
  else
    code <<-EOH
	echo "WARN: Unexpected OS distribution: #{node["lxc"]["bare_os"]["distribution"]}"
	exit 1
EOH
  end
  # only execute if we use docker.io tools
  only_if do node["lxc"]["use_docker.io"] end
end

# terminate prototype container 
# (lxc::stop_lxc also saves/commits the changes made to the prototype container)
node.set["lxc"]["cont"]["name"] = node["lxc"]["proto"]["name"]
node.set["lxc"]["cont"]["ip_address"] = node["lxc"]["proto"]["ip_address"]
node.set["lxc"]["cont"]["root_path"] = "#{node["lxc"]["root_path"]}/#{node["lxc"]["cont"]["name"]}"
node.set["lxc"]["cont"]["config_file"] = "#{node["lxc"]["cont"]["root_path"]}/config"
node.set["lxc"]["cont"]["root_fs"] = node["lxc"]["proto"]["root_fs"]
include_recipe "lxc::stop_lxc"

bash "proto_cp_resolv_conf" do
  code <<-EOH
	# cp resolv.conf from host to LXC container
	echo "INFO: copying /etc/resolv.conf file from host to container"
	rm -f #{rootfs}/etc/resolv.conf
	cp /etc/resolv.conf #{rootfs}/etc/resolv.conf
EOH
  # don't execute if we use docker.io tools
  not_if do node["lxc"]["use_docker.io"] end
end


bash "proto_install_sshd" do
  code <<-EOH
	echo "INFO: Installing sshd..."
	if [ "#{node["lxc"]["bare_os"]["distribution"]}" == "fedora" ]; then
		# this was suggested by yum during one installation run (to clean outdated metadata)
		yum --enablerepo=fedora clean metadata
		# install packages
		#{chroot_cmd} yum install -y openssh-server openssh-clients > /dev/null
	elif [ "#{node["lxc"]["bare_os"]["distribution"]}" == "ubuntu" ]; then

		existing=`cat #{rootfs}/etc/apt/sources.list | grep universe`
		if [ "$existing" == "" ] && [ "#{node["lxc"]["proto"]["release"]}" != "" ]; then
			echo "deb http://archive.ubuntu.com/ubuntu #{node["lxc"]["proto"]["release"]} universe #restricted multiverse" >> #{rootfs}/etc/apt/sources.list
		fi

		# update package list
		#{chroot_cmd} apt-get update > /dev/null

		# install packages
		export DEBIAN_FRONTEND=noninteractive
		# removed package chkconfig from list (no more available in Ubuntu quantal..)
		#{chroot_cmd} apt-get install -y openssh-server 
	else
		echo "ERROR: Unexpected OS distribution: #{node["lxc"]["bare_os"]["distribution"]}"
		exit 1
	fi
EOH
  # don't execute if we use docker.io tools
  not_if do node["lxc"]["use_docker.io"] end
end

# start prototype container
include_recipe "lxc::start_lxc"

# get IP address of container
ruby_block "get_proto_ip" do
  block do
    node.set["lxc"]["proto"]["ip_address"] = node["lxc"]["cont"]["ip_address"]
    puts "INFO: IP address of prototype container is: #{node["lxc"]["proto"]["ip_address"]}"
  end
  not_if do node["network"]["manage_networking"] end
end

# make sure /tmp directory is preserved over time (365 days) and not flushed on every boot
bash "proto_preserve_tmp_dir" do
  code <<-EOH
	sed -i "s/TMPTIME=.*$/TMPTIME=365/g" #{rootfs}/etc/default/rcS
EOH
  only_if "test -f #{rootfs}/etc/default/rcS"
end

# some scripts require a "qwhich" command
bash "proto_link_commands" do
  code <<-EOH
	ln -s /usr/bin/which /usr/bin/qwhich
EOH
  not_if "which qwhich"
end

# create bash file to execute within container
file "proto_setup_inside_script" do
  path "#{rootfs}/tmp/setup.proto.inside.sh"
  mode "0755"
  content <<-EOH
#!/bin/bash

	# make sure we have a default route
  manage_networking=#{node["network"]["manage_networking"] ? 1 : 0}
  if [ $manage_networking == 1 ]; then
    ip route del default
    ip route add default via #{node["network"]["gateway"]}
  fi

	# sometimes the DNS is not immediately available and lookup of google.com fails
	for i in {1..10}; do
		ping -c 1 google.com && break
		if [ "$i" == "10" ]; then
			echo "WARN: Cannot connect out of prototype container"
			cat /etc/resolv.conf
		fi
		sleep 1
	done

	# setup transparent proxy forwarding
	existing=`iptables -t nat -L OUTPUT 2>&1| grep 3128 | grep DNAT`
	if [ "$existing" == "" ] && [ "#{node["lxc"]["cont"]["proxy_ip"]}" != "" ]; then
		echo "INFO: Inside prototype: Setting up local iptables for proxy at '#{node["lxc"]["cont"]["proxy_ip"]}:3128'"
		if [ -f "/etc/init.d/iptables" ]; then
			/etc/init.d/iptables start
		fi
		iptables -t nat -A OUTPUT -p tcp --dport 80 -j DNAT --to #{node["lxc"]["cont"]["proxy_ip"]}:3128
	fi

	# ensure group "admin" exists (required for some software packages)
	existing=`groups | grep admin`
	if [ "$existing" == "" ] && [ -f /usr/sbin/addgroup ]; then
		/usr/sbin/addgroup "admin"
		usermod -a -G "admin" "root"
	fi

	# update installation of Ruby using RVM
	existing=`cat /root/.bashrc | grep "rvm use"`
	if [ "`which ruby`" == "" ] || [ "`ruby -v | grep 1.8.7`" != "" ] || [ "$existing" == "" ]; then

		# the code below contains the platform-specific ruby installation code
		#{node['ruby']['install_script'][node['lxc']['bare_os']['distribution']]}

	fi

	# update all gem packages
	gem update --no-ri --no-rdoc

	# install chef-solo (chef gem), if necessary
	existing=`which chef-solo > /dev/null 2>&1`
	if [ "$existing" == "" ]; then
		gem install --no-ri --no-rdoc chef
	fi

	# install prerequisite for gem mysql2, needed by cloud-toaster
  sudo apt-get install -y libmysqlclient-dev

	# install toaster gem
  gem install --no-ri --no-rdoc cloud-toaster

EOH
end

bash "proto_install_packages" do
  code <<-EOH
	echo "INFO: Installing packages, please be patient..."

	name="#{node["lxc"]["proto"]["name"]}"
	ip=`cat #{node["lxc"]["root_path"]}/$name/container.ip | head -n 1`
	echo "INFO: Installation will ssh to '#{node["lxc"]["proto"]["ssh_user"]}@$ip'"
	ssh_cmd="ssh #{node["lxc"]["proto"]["ssh_user"]}@$ip"

	if [ "#{node["lxc"]["bare_os"]["distribution"]}" == "fedora" ]; then
		install_cmd="$ssh_cmd yum install -y"
	elif [ "#{node["lxc"]["bare_os"]["distribution"]}" == "ubuntu" ]; then
		install_cmd="$ssh_cmd apt-get install -y"
	else
		echo "WARN: Unexpected OS distribution: #{node["lxc"]["bare_os"]["distribution"]}"
		exit 1
	fi

	# Install packages inside the container.
	# --> The plain vanilla LXC container does not contain often-used 
	# binaries like /usr/bin/test or /usr/bin/host or /sbin/ifconfig, 
	# so we are well advised to install all the packages listed below 
	# (and possibly more)..
	if [ "#{node["lxc"]["bare_os"]["distribution"]}" == "fedora" ]; then
	
		# this was suggested by yum during one installation run (to clean outdated metadata)
		yum --enablerepo=fedora clean metadata
	
		# install packages
		$install_cmd man openssh-server openssh-clients screen curl wget unzip which tar bind-utils sh-utils lsof > /dev/null

	elif [ "#{node["lxc"]["bare_os"]["distribution"]}" == "ubuntu" ]; then

		existing=`cat #{rootfs}/etc/apt/sources.list | grep universe`
		if [ "$existing" == "" ] && [ "#{node["lxc"]["proto"]["release"]}" != "" ]; then
			echo "deb http://archive.ubuntu.com/ubuntu #{node["lxc"]["proto"]["release"]} universe #restricted multiverse" >> #{rootfs}/etc/apt/sources.list
		fi
	
		# update package list
		$ssh_cmd apt-get update > /dev/null

		# install packages
		export DEBIAN_FRONTEND=noninteractive
		# removed package chkconfig from list (no more available in Ubuntu quantal..)
		# removed package iptables-persistent from list
		$install_cmd openssh-server net-tools dnsutils iputils-ping iptables vim make > /dev/null

		# make sure to uninstall previous Ruby versions
		$ssh_cmd apt-get remove -yf ruby1.8
	fi
EOH
end

# run setup scripts inside prototype
bash "proto_setup_inside" do
  code <<-EOH
	name="#{node["lxc"]["proto"]["name"]}"
        ip=`cat #{node["lxc"]["root_path"]}/$name/container.ip | head -n 1`

	echo "INFO: Running configuration script inside prototype; ssh'ing to #{node["lxc"]["proto"]["ssh_user"]}@$ip as user: `whoami`"
	echo "DEBUG: running: ssh #{node["lxc"]["proto"]["ssh_user"]}@$ip /tmp/setup.proto.inside.sh"
	# #{chroot_cmd} /usr/sbin/sshd
	ssh #{node["lxc"]["proto"]["ssh_user"]}@$ip /tmp/setup.proto.inside.sh
EOH
end

# terminate prototype container 
# (lxc::stop_lxc also saves/commits the changes made to the prototype container)
bash 'commit_docker_final' do
  code 'echo'
  notifies :run, 'bash[lxc_docker_commit]', :immediately
  notifies :run, 'bash[lxc_stop]', :immediately
  notifies :run, 'bash[lxc_stop_proto]', :immediately
end
