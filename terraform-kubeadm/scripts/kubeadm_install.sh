#!/bin/sh

# This script aims to install kubeadm on Debian based host
# Notes:
#  - this script install only packages on the hosts, controlplane & nodes are created in others scripts. 
#  - differents env var are used in this script (all starting with "COSMO_KUBERNETES")


COSMO_KUBERNETES_VERSION='1.35'
echo "COSMO_KUBERNETES_VERSION=$COSMO_KUBERNETES_VERSION"


# Stop script if not sudo
if [ "$(id -u)" != "0" ]; then
  echo "sudo is required"
  exit
fi


# Get the name of the current Linux distribution
# Usage: get_os_distribution
get_os_distribution(){
  cat /etc/os-release | grep -w ID | cut -d= -f2
}


# Stop script if unsupported distribution
DISTRIBUTION="$(get_os_distribution)"
if [ "$DISTRIBUTION" = 'debian' ] || [ "$DISTRIBUTION" = 'ubuntu' ]; then
  continue
else
  echo "error: unsupported Linux distribution '$DISTRIBUTION'"
  exit
fi


# Stop script if missing dependency
required_commands="apt swapoff curl systemctl"
for command in $required_commands; do
    if [ -z "$(command -v $command)" ]; then
        echo "error: required command not found: $command"
        exit 1
    fi
done


# Stop script if component already installed
components_list="containerd kubeadm kubelet kubectl"
for component in $components_list; do
	if [ "$(command -v $component)" ] || [ "$(sudo systemctl status $component | grep -w 'Active:')" ] || [ "$(dpkg -l | grep -w $component)" ]; then
    echo "info: component already installed: $component"
    at_least_one_component_exists='true'
	fi
done
if [ "$at_least_one_component_exists" = 'true' ]; then
  exit
fi


# Deactivate swap
# Usage: deactivate_swap
deactivate_swap() {
  # current runtime
  sudo swapoff -a 

  # persistence
  sudo sed -i 's|\(.*swap.*\)|#\1|' /etc/fstab
}


# Install containerd
# Usage: install_containerd 
install_containerd() {
  sudo apt remove -y $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1)

  if [ "$DISTRIBUTION" = 'debian' ]; then
    # Add Docker's official GPG key:
    sudo apt update
    sudo apt install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo " \
      Types: deb
      URIs: https://download.docker.com/linux/debian
      Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
      Components: stable
      Signed-By: /etc/apt/keyrings/docker.asc
    " > '/etc/apt/sources.list.d/docker.sources'

  elif [ "$DISTRIBUTION"= 'ubuntu' ]; then
    # Add Docker's official GPG key:
    sudo apt update
    sudo apt install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo " \
      Types: deb
      URIs: https://download.docker.com/linux/ubuntu
      Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
      Components: stable
      Signed-By: /etc/apt/keyrings/docker.asc
    " > '/etc/apt/sources.list.d/docker.sources'
  fi

  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  sudo mkdir -p /etc/containerd
  sudo containerd config default | sudo tee /etc/containerd/config.toml
  sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
  sudo systemctl restart containerd
}


# Install kubernetes components
# Usage: install_kube 
install_kube() {
  echo " \
    overlay
    br_netfilter
    TEST
  " > '/etc/modules-load.d/k8s.conf'
  sudo modprobe overlay
  sudo modprobe br_netfilter

  echo " \
    net.bridge.bridge-nf-call-ip6tables = 1
    net.bridge.bridge-nf-call-iptables = 1
  " > '/etc/sysctl.d/k8s.conf'
  sudo sysctl --system

  sudo apt update
  sudo apt install -y apt-transport-https ca-certificates curl gpg
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v$COSMO_KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$COSMO_KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

  sudo apt update
  sudo apt install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl

  sudo systemctl enable --now kubelet
}


deactivate_swap
install_containerd
install_kube



exit
