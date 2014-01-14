
# save changes of prototype container with docker
bash "lxc_docker_commit" do
  code <<-EOH
  cont_name=#{node["lxc"]["cont"]["name"]}
  ip_address=#{node["lxc"]["cont"]["ip_address"]}
  imgID=`cat /lxc/$cont_name/docker.image.id`
  instID=`cat /lxc/$cont_name/docker.container.id`
  if [ "$imgID" == "" ] || [ "$instID" == "" ]; then
    echo "WARN: Invalid image ID or instance ID for prototype '$cont_name': '$imgID', '$instID'"
    exit 1
  fi
  cp /var/lib/docker/containers/$instID/config.lxc /lxc/$cont_name/config
  echo "lxc.network.ipv4 = $ip_address/16" >> /lxc/$cont_name/config
  newImgID=`docker commit $instID prototypes $cont_name`
  if [ "$newImgID" != "" ]; then
    # remove old docker image
    docker rmi $imgID
    # update new image id
    echo $newImgID > /lxc/$cont_name/docker.image.id
  else
    echo "WARN: Unable to save/commit prototype with docker (invalid new image ID received)"
  fi
EOH
  # only execute if we use docker.io tools
  only_if do node["lxc"]["use_docker.io"] end
  # only execute if this is a prototype container
  only_if do node["lxc"]["cont"]["name"].match(/^prototype_.*/) end
end

bash "lxc_stop" do
  if node["lxc"]["use_docker.io"] 
  code <<-EOH
	name=#{node["lxc"]["cont"]["name"]}
	contID=`cat /lxc/$name/docker.container.id`
	docker kill $contID
EOH
  else
  code <<-EOH
	name=#{node["lxc"]["cont"]["name"]}
	lxc-stop -n $name
	version=`lxc-version`
	if [ "${version:0:3}" == "0.7" ]; then
		lxc-destroy -n #{node["lxc"]["cont"]["name"]}
	else
		# WARN: starting with LXC 0.8.0, lxc-destroy deletes the rootfs!

		if [ #{node["lxc"]["use_copy_on_write"] ? 1 : 0} ]; then
			mv /lxc/$name /lxc/$name.copy
			#/sbin/btrfs subvolume snapshot /lxc/$name /lxc/$name.copy
			lxc-destroy -n $name
			#/sbin/btrfs subvolume delete /lxc/$name
		else
			cp -r /lxc/$name /lxc/$name.copy
			lxc-destroy -n $name
			rm -r /lxc/$name
		fi
		mv /lxc/$name.copy /lxc/$name
	fi
EOH
  end
end

bash "lxc_stop_proto" do
  code <<-EOH
	# do some additional tasks for prototypes

	echo "INFO: Resetting /etc/resolv.conf within prototype to a symlink"
	# reset /etc/resolv.conf to symlink
	rm -f #{node["lxc"]["cont"]["root_fs"]}/etc/resolv.conf
	ln -s /etc/resolv.conf #{node["lxc"]["cont"]["root_fs"]}/etc/resolv.conf
EOH
  only_if do node["lxc"]["cont"]["name"].match(/^prototype_.*/) end
  # don't execute if we use docker.io tools
  not_if do node["lxc"]["use_docker.io"] end
end

