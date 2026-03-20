#!/bin/sh

# This script allows to easily install Longhorn requirements on Linux hosts


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
linux_distribution="$(get_os_distribution)"
if [ "$linux_distribution" = 'debian' ] || [ "$linux_distribution" = 'ubuntu' ]; then
  continue
else
  echo "error: unsupported Linux distribution '$linux_distribution'"
  exit 1
fi


# Longhorn will requires to have some packages installed on the host
# https://longhorn.io/docs/1.11.1/deploy/install/#installation-requirements
# Usage: install_longhorn_requirements
install_longhorn_requirements() {
  required_commands="bash curl findmnt grep awk blkid lsblk"
  for command in $required_commands; do
    if [ -z "$(command -v $command)" ]; then
      echo "error: required command not found: $command"
      exit 1
    fi
  done

  sudo apt update
  sudo apt install -y open-iscsi
}


install_longhorn_requirements


echo ''
exit
