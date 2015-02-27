define docker::image ($imagerepo, $imagetag, $buildcontext) {
    exec { "docker build -t ${$imagerepo}:${imagetag} .":
        cwd    => "/home/oliver/Projects/citac/docker/images/${$buildcontext}",
        path   => "/usr/bin:/usr/sbin:/bin",
        unless => "docker images ${$imagerepo} | grep ${imagetag}"
    }
}

# CentOS 7

docker::image { 'citac:centos-7' :
    imagerepo    => 'citac',
    imagetag     => 'centos-7',
    buildcontext => 'citac/centos-7'
}

docker::image { 'citac/puppet:centos-7' :
    imagerepo    => 'citac/puppet',
    imagetag     => 'centos-7',
    buildcontext => 'citac-puppet/centos-7',
    require      => Docker::Image['citac:centos-7']
}

# Debian 7

docker::image { 'citac:debian-7' :
    imagerepo    => 'citac',
    imagetag     => 'debian-7',
    buildcontext => 'citac/debian-7'
}

docker::image { 'citac/puppet:debian-7' :
    imagerepo    => 'citac/puppet',
    imagetag     => 'debian-7',
    buildcontext => 'citac-puppet/debian-7',
    require      => Docker::Image['citac:debian-7']
}

# Ubuntu 14.04

docker::image { 'citac:ubuntu-14.04' :
    imagerepo    => 'citac',
    imagetag     => 'ubuntu-14.04',
    buildcontext => 'citac/ubuntu-14.04'
}

docker::image { 'citac/puppet:ubuntu-14.04' :
    imagerepo    => 'citac/puppet',
    imagetag     => 'ubuntu-14.04',
    buildcontext => 'citac-puppet/ubuntu-14.04',
    require      => Docker::Image['citac:ubuntu-14.04']
}