# Installation

The installation assumes that the source code is checked out to `/opt/citac`.

## Ubuntu 14.04

    # run as root

    sudo su

    # install prerequisites

    apt-get update
    apt-get install -y ruby graphviz apparmor-utils

    gem install --no-ri --no-rdoc thor rest-client

    # install docker

    curl -sSL https://get.docker.com/ubuntu/ | sh

    # register citac executable

    ln -s /opt/citac/bin/citac /usr/bin/citac

    # build docker images

    citac envs setup

# Troubleshooting

## docker fails to start containers and commit images

On Ubuntu 14.04 there may be issues with docker's underlying storage engine `devicemapper`.
Run `docker info` and check whether devicemapper is used as Storage Driver and udev sync support
is not available. In such a case switch to AUFS as Storage Engine with the following command
to resolve the problem:

    sudo apt-get -y install linux-image-extra-$(uname -r)

GitHub Issue:

 * [https://github.com/docker/docker/issues/4036](https://github.com/docker/docker/issues/4036)

