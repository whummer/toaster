#!/bin/bash

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

if [ $(whoami) != "root" ]; then
    echo "Please run this script as root."
    exit 1
fi

if command_exists docker; then
    echo "Docker is already installed."
else
    echo "Installing docker..."
    curl -sSL https://get.docker.com/ | sh
fi

if [ -e /etc/apparmor.d/docker-ptrace ]; then
    echo "AppArmor configured appropriately."
else
    echo "Configuring AppArmor ..."
    # https://github.com/mconcas/docks#allow-docker-container-to-call-ptrace

    curl -sSL https://raw.githubusercontent.com/citac/citac/master/install/docker-ptrace > /tmp/docker-ptrace
    apparmor_parser -r /tmp/docker-ptrace
    mv /tmp/docker-ptrace /etc/apparmor.d
fi

if docker images | grep "citac\s*latest"; then
    echo "citac docker image already generated."
else
    echo "Generating citac docker image..."

    rm -rf /tmp/citac
    mkdir /tmp/citac
    curl -sSL https://raw.githubusercontent.com/citac/citac/master/install/docker-image/Dockerfile > /tmp/citac/Dockerfile
    docker build -t citac /tmp/citac
    rm -rf /tmp/citac
fi

if command_exists citac; then
    echo "citac command already installed."
else
    curl -sSL https://raw.githubusercontent.com/citac/citac/master/install/citac > /usr/bin/citac
    chmod +x /usr/bin/citac
fi

if docker images | grep "citac_environment"; then
    echo "citac environment docker image already generated."
else
    echo "Generating citac environment docker images..."

    citac adv envs setup -p
fi

