
rootfs = node["lxc"]["cont"]["root_fs"]

bash "lxc_prepare_proto" do
  code <<-EOH
	# do some additional tasks for prototypes
	echo "INFO: Turn /etc/resolv.conf symlink within prototype into actual file"
	# turn /etc/resolv.conf symlink into actual file
	rm -f #{node["lxc"]["cont"]["root_fs"]}/etc/resolv.conf
	cp /etc/resolv.conf #{node["lxc"]["cont"]["root_fs"]}/etc/resolv.conf
	# enable forwarding on the host
	echo 1 > /proc/sys/net/ipv4/ip_forward
EOH
  only_if do node["lxc"]["cont"]["name"].match(/^prototype_.*/) end
  # don't execute if we use docker.io tools
  not_if do node["lxc"]["use_docker.io"] end
end

if node["lxc"]["use_docker.io"]
  bash "lxc_start" do
    code <<-EOH
	ip_addr=#{node["lxc"]["cont"]["ip_address"]}
	name=#{node["lxc"]["cont"]["name"]}
	proto_name=#{node["lxc"]["proto"]["name"]}
  manage_networking=#{node["network"]["manage_networking"] ? 1 : 0}
  if [ $manage_networking == 1 ]; then
    network_setup="ifconfig eth0 $ip_addr && route add default gw #{node["network"]["gateway"]}"
  else
    network_setup="echo" #noop
  fi
	echo "$proto_name" >> /tmp/tmp.lxc.protos
	if [ "$proto_name" == "" ]; then
		proto_name=`cat #{node["lxc"]["root_path"]}/$name/container.prototype.name`
	fi
	echo "$proto_name" >> /tmp/tmp.lxc.protos
	if [ "$proto_name" == "" ]; then
		proto_name=#{node["lxc"]["cont"]["name"]}
	fi
	cidfile=#{node["lxc"]["root_path"]}/$name/docker.container.id
	rm -f $cidfile
	screen -m -d docker run --cidfile=$cidfile --privileged prototypes:$proto_name bash -c "$network_setup && /usr/sbin/sshd -D"
	echo "INFO: LXC container '#{node["lxc"]["cont"]["name"]}' started in the background using 'screen'."
	sleep 2
	#contID=`docker ps | grep -v IMAGE | head -n 1 | awk '{print $1}'`
  contID=`cat "$cidfile"`
	if [ "$contID" == "" ]; then
		echo "WARN: Container could not be started. Name '$name', prototype '$proto_name', IP '$ip_addr'"
		exit 1
	fi
	#contID=`ls /var/lib/docker/containers/ | grep "$contID"`
  echo "$contID" >> /tmp/tmp.lxc.cont.ids
	rm -f #{node["lxc"]["root_path"]}/$name/rootfs

	# create a symlink to the rootfs folder. This 
	# differs in different versions of docker.. :/
	if [ -d /var/lib/docker/aufs/mnt/$contID ]; then
    ln -s /var/lib/docker/aufs/mnt/$contID #{node["lxc"]["root_path"]}/$name/rootfs
	elif [ -d /var/lib/docker/containers/$contID/rootfs ]; then
    ln -s /var/lib/docker/containers/$contID/rootfs #{node["lxc"]["root_path"]}/$name/rootfs
	else
    # TODO: fix for Mac OS (boot2docker) where docker runs inside a Linux VM in
    # Virtualbox and hence we don't have direct access to the file system
	  echo "ERROR: Unable to determine container root directory."
	  exit 1
	fi

EOH
  end
else
  bash "lxc_start" do
    code <<-EOH
	lxc-create -f #{node["lxc"]["cont"]["config_file"]} -n #{node["lxc"]["cont"]["name"]}
	screen -m -d lxc-start -n #{node["lxc"]["cont"]["name"]}
	echo "INFO: LXC container '#{node["lxc"]["cont"]["name"]}' started in the background using 'screen'."
	sleep 3
EOH
  end
end


bash "auth_ssh" do
  code <<-EOH
	# authorize local ssh public key within container
	if [ ! -f "/root/.ssh/id_rsa" ]; then
		ssh-keygen -N "" -f /root/.ssh/id_rsa
	fi
	mkdir -p #{rootfs}/root/.ssh
	touch #{rootfs}/root/.ssh/authorized_keys
	key=`cat /root/.ssh/id_rsa.pub | head -n 1 | awk '{print $2}'`
	existing=`cat #{rootfs}/root/.ssh/authorized_keys | grep "$key"`
	if [ "$existing" == "" ]; then
		cat /root/.ssh/id_rsa.pub >> #{rootfs}/root/.ssh/authorized_keys
	fi

	# make sure we have the right permissions (ssh will fail on too loose permissions)
	chmod 700 #{rootfs}/root/.ssh
	chmod 600 #{rootfs}/root/.ssh/authorized_keys
	
EOH
end

bash "lxc_adjust_iptables" do
  code <<-EOH
	iptables -F
EOH
  only_if "iptables -L | grep REJECT | grep all"
end

ruby_block "get_container_ip" do
  block do
    name = node["lxc"]["cont"]["name"]
    cidfile = "#{node["lxc"]["root_path"]}/#{name}/docker.container.id"
    #puts "DEBUG: Getting container ID from file '#{cidfile}'"
    cid = `cat #{cidfile}`
    ip = `docker inspect #{cid} | grep IPAddress | awk '{print $2}' | sed 's/[",]*//g'`
    ip = "#{ip}".strip
    puts "INFO: IP address of container '#{cid}' is: #{ip}"
    node.set["lxc"]["cont"]["ip_address"] = ip
  end
  only_if do node["lxc"]["use_docker.io"] end
  not_if do node["network"]["manage_networking"] end
end

ruby_block "store_container_ip" do
  block do
    name = node["lxc"]["cont"]["name"]
    ipfile = "#{node["lxc"]["root_path"]}/#{name}/container.ip"
    ip = node["lxc"]["cont"]["ip_address"]
    ip = "#{ip}".strip
    `echo '#{ip}' > #{ipfile}`
    # set IP subnet pattern for SSH settings; used in next resource (ssh::permit_subnet)
    node.set["ssh"]["permit_subnet_pattern"] = ip.gsub(/[0-9]+$/, "*")
    puts "DEBUG: IP addr #{ip}, subnet #{node["ssh"]["permit_subnet_pattern"]}"
  end
end

# configure SSH settings to disable strict host checking when connecting to LXC containers
include_recipe "ssh::permit_subnet"

# sometimes the network is not immediately available
bash "lxc_wait_for_connectivity" do
  code <<-EOH
  	ip=`cat #{node["lxc"]["root_path"]}/#{name}/container.ip`
  	echo "INFO: ssh'ing into '$ip'"
	for i in {1..10}; do
		ssh $ip echo && break
		sleep 1
		if [ "$i" == "10" ]; then
			echo "WARN: Unable to ssh into new container."
		fi
	done
EOH
  only_if do node["network"]["manage_networking"] end
end

file "lxc_create_setup_script" do
  path "#{node["lxc"]["cont"]["root_fs"]}/tmp/setup.instance.inside.sh"
  mode "0755"
  content <<-EOH
#!/bin/bash

	# make sure we have a default route
	existing=`route | grep "^default"`
	manage_networking=#{node["network"]["manage_networking"] ? 1 : 0}
	if [ "$existing" == "" ] && [ $manage_networking == 1 ]; then
		route add default gw #{node["network"]["gateway"]}
		echo
	fi

	# this should fix problems with TTY when trying to ssh into ubuntu container
	if [ "#{node["lxc"]["bare_os"]["distribution"]}" != "fedora" ]; then
		mount -t devpts none /dev/pts -o rw,noexec,nosuid,gid=5,mode=0620 2> /dev/null
		echo
	fi

	# setup transparent proxy forwarding
	existing=`iptables -t nat -L OUTPUT | grep 3128 | grep DNAT`
	proxy="#{node["lxc"]["cont"]["proxy_ip"]}"
	if [ $manage_networking == 0 ]; then
		# get default gateway
		proxy=`route -n | grep "^0.0.0.0" | awk '{print $2}'`
        fi
	if [ "$existing" == "" ] && [ "$proxy" != "" ]; then
		echo "INFO: Setting up local iptables for transparent proxy residing under '$proxy:3128'"
		if [ -f "/etc/init.d/iptables" ]; then
			/etc/init.d/iptables start
		fi
		iptables -t nat -A OUTPUT -p tcp --dport 80 -j DNAT --to $proxy:3128
	fi

	exit 0
EOH
end

bash "lxc_setup_inside" do
  code <<-EOH
	# again, wait for connectivity
	ip=`cat #{node["lxc"]["root_path"]}/#{node["lxc"]["cont"]["name"]}/container.ip`
	echo "INFO: ssh'ing into '$ip'"
	for i in {1..3}; do
		ssh $ip echo && break
		sleep 2
		if [ "$i" == "3" ]; then
			echo "WARN: Unable to ssh into new container."
			exit 1
		fi
	done
	# ssh into the container and run config scripts from there
	echo "INFO: ssh'ing into the LXC container at '$ip' to perform some configurations."
	ssh $ip /tmp/setup.instance.inside.sh
EOH
end

bash "lxc_wait_for_dns" do
  code <<-EOH
	ip=`cat #{node["lxc"]["root_path"]}/#{node["lxc"]["cont"]["name"]}/container.ip`
	# sometimes DNS is not immediately available
	for i in {1..15}; do
		ssh $ip ping -c 1 www.google.com && break
		sleep 1
		if [ "$i" == "20" ]; then
			echo "WARN: Unable to ssh into new container and ping host 'www.google.com'."
			exit 1
		fi
	done
EOH
  only_if do node["network"]["manage_networking"] end
end
