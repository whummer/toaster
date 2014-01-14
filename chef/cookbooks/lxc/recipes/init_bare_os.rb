
cache="#{node["lxc"]["bare_os"]["cachedir"]}"

bash "os_init" do
  code <<-EOH
    INSTALL_ROOT=#{cache}/partial
    mkdir -p $INSTALL_ROOT
    if [ $? -ne 0 ]; then
		echo "Failed to create '$INSTALL_ROOT' directory"
		exit 1
    fi
EOH
  # don't execute if we use docker.io tools
  not_if do node["lxc"]["use_docker.io"] end
end

bash "os_download" do

  if node["lxc"]["bare_os"]["distribution"] == "ubuntu"
	code <<-EOH

    	INSTALL_ROOT=#{cache}/partial

	    # download latest version of debootstrap
	    if [ ! -f /usr/share/debootstrap/scripts/#{node["lxc"]["bare_os"]["release"]} ]; then
			wget ftp://fr2.rpmfind.net/linux/fedora/linux/updates/17/i386/debootstrap-1.0.42-1.fc17.noarch.rpm -O /tmp/debootstrap-1.0.42-1.fc17.noarch.rpm
			if [ -s /tmp/debootstrap-1.0.42-1.fc17.noarch.rpm ]; then
				yum install -y --nogpgcheck /tmp/debootstrap-1.0.42-1.fc17.noarch.rpm
			else
				yum install -y debootstrap
			fi
	    fi
	
	    # download a mini OS into a cache
	    echo "Downloading ubuntu minimal ..."
	    yum update --skip-broken -y
	    
	    # on some systems "gpgv" has been renamed to "gpgv2"
	    if [ "`which gpgv`" == "" ]; then
		ln -s /usr/bin/gpgv2 /usr/bin/gpgv
	    fi

	    if [ ! -f /usr/share/keyrings/ubuntu-archive-keyring.gpg ]; then
			mkdir -p /usr/share/keyrings/
			wget http://archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg -O /usr/share/keyrings/ubuntu-archive-keyring.gpg
	    fi
	    debootstrap --verbose --arch #{node["lxc"]["bare_os"]["arch"]} --variant=minbase --include console-setup #{node["lxc"]["bare_os"]["release"]} $INSTALL_ROOT
	
	    # sometimes debootstrap fails on some packages, e.g., cron and rsyslog. Re-install here
	    #{node["path"]["chroot"]} $INSTALL_ROOT apt-get update --skip-broken -y
	    #{node["path"]["chroot"]} $INSTALL_ROOT apt-get remove -y cron rsyslog
	    #{node["path"]["chroot"]} $INSTALL_ROOT apt-get upgrade -y
	
	    # disable udevd on startup
	    for f in `ls $INSTALL_ROOT/etc/init/*udev*`; do
			mv "$f" "$f.bak"
	    done
	
	    # add additional repositories
	    existing=`cat $INSTALL_ROOT/etc/apt/sources.list | grep universe`
	    if [ "$existing" == "" ]; then
	        echo "deb http://archive.ubuntu.com/ubuntu #{node["lxc"]["bare_os"]["release"]} universe #restricted multiverse" >> $INSTALL_ROOT/etc/apt/sources.list
	    fi
	
	    #{node["path"]["chroot"]} $INSTALL_ROOT apt-get update
	    #{node["path"]["chroot"]} $INSTALL_ROOT apt-get install -y passwd #rsyslog chkconfig

	    mv "$INSTALL_ROOT" "#{cache}/rootfs"
	    echo "Download complete."
EOH
  elsif node["lxc"]["bare_os"]["distribution"] == "fedora"
    code <<-EOH
      echo "ERROR: Fedora is currenly not supported."
      exit 1
    EOH
  end

  not_if "test -e '#{cache}/rootfs'"
  # don't execute if we use docker.io tools
  not_if do node["lxc"]["use_docker.io"] end
end

