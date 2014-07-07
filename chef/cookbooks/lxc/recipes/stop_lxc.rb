
# save changes of prototype container with docker
bash "lxc_docker_commit" do
  code <<-EOH
  cont_name=#{node["lxc"]["cont"]["name"]}
  ip_address=#{node["lxc"]["cont"]["ip_address"]}
  root_path=#{node["lxc"]["root_path"]}

  imgID=`cat $root_path/$cont_name/docker.image.id`
  instID=`cat $root_path/$cont_name/docker.container.id`
  if [ "$imgID" == "" ] || [ "$instID" == "" ]; then
    echo "WARN: Invalid image ID or instance ID for prototype '$cont_name': '$imgID', '$instID'"
    exit 1
  fi
  # TODO config.lxc now renamed to config.json in new docker versions!
  cp /var/lib/docker/containers/$instID/config.lxc $root_path/$cont_name/config
  echo "lxc.network.ipv4 = $ip_address/16" >> $root_path/$cont_name/config
  newImgID=`docker commit $instID prototypes "$cont_name"` # old syntax
  if [ "$newImgID" == "" ]; then
    newImgID=`docker commit $instID prototypes:$cont_name` # new syntax
  fi
  if [ "$newImgID" != "" ]; then
    # remove old docker image
    docker rmi $imgID
    # update new image id
    echo $newImgID > $root_path/$cont_name/docker.image.id
  else
    echo "WARN: Unable to save/commit prototype with docker (invalid new image ID received)"
    exit 1
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
	contID=`cat #{node["lxc"]["root_path"]}/$name/docker.container.id`
  docker kill $contID
  docker rm $contID
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
	  root_path=#{node["lxc"]["root_path"]}

		if [ #{node["lxc"]["use_copy_on_write"] ? 1 : 0} ]; then
			mv $root_path/$name $root_path/$name.copy
			#/sbin/btrfs subvolume snapshot $root_path/$name $root_path/$name.copy
			lxc-destroy -n $name
			#/sbin/btrfs subvolume delete $root_path/$name
		else
			cp -r $root_path/$name $root_path/$name.copy
			lxc-destroy -n $name
			rm -r $root_path/$name
		fi
		mv $root_path/$name.copy $root_path/$name
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

