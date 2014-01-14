
# install squid
#package "squid" do
#  action :install
#  not_if "which squid"
#end
# due to some recent changes in squid, we have to use version <= 3.1 (--> manual install)
bash "proxy_install_squid" do
  code <<-EOH
	rm -rf /tmp/squidSetup
	mkdir -p /tmp/squidSetup
	cd /tmp/squidSetup
	echo "INFO: Downloading squid archive"
	squid_version=3.1.21
	squid_shortversion=3.1
	#squid_version=3.3.8
	#squid_shortversion=3.3

	wget http://www.squid-cache.org/Versions/v3/$squid_shortversion/squid-$squid_version.tar.gz -O squid-$squid_version.tar.gz
	gzip -d squid-$squid_version.tar.gz
	tar xf squid-$squid_version.tar
	cd squid-$squid_version

	# do NOT treat compile warnings as errors:
	sed -i "s/-Werror//g" configure

	./configure
	echo "INFO: Compiling squid binary, please be patient."
	make > /dev/null
	make install
EOH
  not_if "which squid"
end

# link squid binary, config, and log files
bash "proxy_link_squid" do
  code <<-EOH
	ln -s /usr/local/squid/sbin/squid /usr/sbin/squid
	chmod 777 /usr/local/squid/var/logs/
	ln -s /usr/local/squid/var/logs/ /var/log/squid
	mkdir -p /etc/squid
	if [ -e /etc/squid/squid.conf ]; then
		mv /etc/squid/squid.conf /etc/squid/squid.conf.bak
	fi
	mv /usr/local/squid/etc/squid.conf /etc/squid/squid.conf
	# do not symlink the other way around..! The "sed -i" command later will 
	# turn /etc/squid/squid.conf into a regular file, even if it's a symlink...
	# https://bugs.launchpad.net/ubuntu/+source/sed/+bug/367211
	ln -s /etc/squid/squid.conf /usr/local/squid/etc/squid.conf
EOH
  # "test -L" tests for symbolic link
  not_if "test -L /usr/local/squid/etc/squid.conf"
end

# setup iptables for transparent use of squid proxy
bash "proxy_setup_iptables" do
  code <<-EOH
	echo "INFO: Setting up local iptables for transparent proxy"
	/sbin/iptables -t nat -A OUTPUT -p tcp --dport 80 -m owner ! --uid-owner squid -j REDIRECT --to-ports 3128
EOH
  only_if do node["lxc"]["host"]["use_proxy"] end
  not_if "/sbin/iptables -t nat -L OUTPUT | grep 3128 | grep REDIRECT"
end

# create cache directory
bash "proxy_create_cache_dir" do
  code <<-EOH
	mkdir -p #{node["lxc"]["proxy"]["cache_dir"]}
	chmod 777 #{node["lxc"]["proxy"]["cache_dir"]}
EOH
  only_if do node["lxc"]["host"]["use_proxy"] end
  only_if do node["lxc"]["proxy"]["cache_dir"] != "" end
  not_if "test -d #{node["lxc"]["proxy"]["cache_dir"]}"
end

# update squid config
bash "proxy_squid_config" do
  code <<-EOH
  	# allow machines from certain subnets to access squid 
	# TODO make configurable
	echo "acl localnet src 9.0.0.0/8" >> /etc/squid/squid.conf
	echo "acl localnet src 128.131.0.0/16" >> /etc/squid/squid.conf
	echo "acl localnet src 128.130.0.0/16" >> /etc/squid/squid.conf

	# use squid cache directory
	if [ "#{node["lxc"]["proxy"]["cache_dir"]}" != "" ]; then
		echo "cache_dir ufs #{node["lxc"]["proxy"]["cache_dir"]} 200000 16 256 max-size=100000000" >> /etc/squid/squid.conf
	fi

	# increase maximum file size
	echo "maximum_object_size 50000 KB" >> /etc/squid/squid.conf

	# set refresh patterns/intervals
	sed -i '1refresh_pattern github 60 20% 4320 override-expire ignore-private' /etc/squid/squid.conf

	# don't cache files from certain servers
	echo "#no_cache deny dont_cache" >> /etc/squid/squid.conf
	echo "" >> /etc/squid/squid.conf

	# make sure squid runs in "transparent" mode
	sed -i 's/\\(http_port .*\\)$/#\\1/g' /etc/squid/squid.conf
	echo "http_port 3128 transparent" >> /etc/squid/squid.conf
	echo "" >> /etc/squid/squid.conf
	
	# Note 1: this seems to fix an error related to some clients (git?) not handling "Expect: 100-continue" headers correctly
	# see http://drupal.org/node/1101210
	# Note 2: Dont add, because: "ERROR: Directive 'ignore_expect_100' is obsolete."
	#echo "ignore_expect_100 on" >> /etc/squid/squid.conf

	echo "#toaster_squid_config_added (dont remove this line)" >> /etc/squid/squid.conf

	# force restart in next step below
	if [ -f /etc/init.d/squid ]; then
		/etc/init.d/squid stop
	elif [ "`ps -A | grep squid`" != "" ]; then
		killall squid
		killall squid
	fi
	exit 0
  EOH
  not_if "cat /etc/squid/squid.conf | grep toaster_squid_config_added"
end

# start squid
bash "proxy_squid_start" do
  code <<-EOH
	if [ "#{node["lxc"]["proxy"]["cache_dir"]}" != "" ]; then
		if [ ! -d #{node["lxc"]["proxy"]["cache_dir"]}/00 ]; then
			mkdir /data/squid
			chmod 777 /data/squid

			# force squid to create data directories (-z parameter)..
			screen -d -m /usr/sbin/squid -z
			sleep 4
			killall squid > /dev/null 2>&1
		fi
	fi
	if [ -f /etc/init.d/squid ]; then
		/etc/init.d/squid start
	else
	  # DON'T run via screen! squid will go to background 
	  # automatically and this line fails in EC2
		#screen -d -m /usr/sbin/squid
    /usr/sbin/squid
	fi
  sleep 2
  running=`ps -A | grep squid`
	if [ "$running" == "" ]; then
	  echo "ERROR: Squid failed to start using '/usr/sbin/squid'."
	  exit 1
	end
	fi
EOH
  not_if "ps -A | grep squid"
end


