# Installation

The installation assumes that the source code is checked out to `/opt/citac`.

## Ubuntu 14.04

    # run as root

    sudo su

    # install prerequisites (ruby, graphviz)    

    apt-get update
    apt-get install -y ruby graphviz

    gem install --no-ri --no-rdoc thor rest-client

    # install docker

    curl -sSL https://get.docker.com/ubuntu/ | sh

    # register citac executable

    ln -s /opt/citac/bin/citac /usr/bin/citac

    # enable strace in docker containers

    apt-get install -y apparmor-utils
    aa-complain /etc/apparmor.d/docker

    # build docker images

    docker build -t citac_environments/base:centos-7 /opt/citac/ext/docker/images/environments-base/centos-7
    docker build -t citac_environments/base:debian-7 /opt/citac/ext/docker/images/environments-base/debian-7
    docker build -t citac_environments/base:ubuntu-14.04 /opt/citac/ext/docker/images/environments-base/ubuntu-14.04

    docker build -t citac_environments/puppet:centos-7 /opt/citac/ext/docker/images/environments-puppet/centos-7
    docker build -t citac_environments/puppet:debian-7 /opt/citac/ext/docker/images/environments-puppet/debian-7
    docker build -t citac_environments/puppet:ubuntu-14.04 /opt/citac/ext/docker/images/environments-puppet/ubuntu-14.04

    docker build -t citac_services/cache:squid /opt/citac/ext/docker/images/services-cache/squid
