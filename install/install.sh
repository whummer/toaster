#!/bin/bash

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

if [ $(whoami) != "root" ]; then
    echo "Please run this script as root."
    exit 1
fi

if command_exists docker; then
    echo "[1 / 4] Docker is already installed."
else
    echo "[1 / 4] Installing Docker..."
    curl -sSL https://get.docker.com/ | sh || exit 1

    echo "[1 / 4] Installed successfully."
fi

if [ -e /etc/apparmor.d/docker-ptrace ]; then
    echo "[2 / 4] AppArmor is already configured appropriately."
else
    echo "[2 / 4] Configuring AppArmor ..."

    curl -sSL https://raw.githubusercontent.com/citac/citac/master/install/docker-ptrace > /etc/apparmor.d/docker-ptrace || exit 1
    apparmor_parser -r /etc/apparmor.d/docker-ptrace || exit 1

    echo "[2 / 4] Configured successfully."
fi


if docker images | grep "citac_environment"; then
    echo "[3 / 4] Citac Docker images are already downloaded."
else
    echo "[3 / 4] Downloading Citac Docker images..."
    docker pull -a citac/environments || exit 1

    echo "[3 / 4] Downloaded successfully."
fi


if command_exists citac; then
    echo "[4 / 4] Citac command is already installed."
else
    echo "[4 / 4] Installing citac command into /usr/bin..."

    curl -sSL https://raw.githubusercontent.com/citac/citac/master/install/citac > /usr/bin/citac || exit 1
    chmod +x /usr/bin/citac || exit 1

    echo "[4 / 4] Installed successfully."
fi

echo "Installation finished."