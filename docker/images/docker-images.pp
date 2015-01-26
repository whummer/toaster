define docker::image ($repository, $imagetag, $buildcontext) {
    exec { "echo \"Building ${respository}:${imagetag}...\"":
        path   => "/usr/bin:/usr/sbin:/bin",
        unless => "docker images ${repository} | grep ${imagetag}"
    }
}

docker::image { 'puppet-ubuntu-trusty' :
    repository   => 'citac',
    imagetag     => 'puppet-ubuntu-trusty',
    buildcontext => '.'
}

docker::image { 'puppet-debian-wheezy' :
    repository   => 'citac',
    imagetag     => 'puppet-debian-wheezy',
    buildcontext => '.'
}


