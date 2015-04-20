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
