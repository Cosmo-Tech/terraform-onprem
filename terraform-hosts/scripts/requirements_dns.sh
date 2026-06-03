#!/bin/sh

# This script aims to configure DNS on the host to make it works on Kubernetes.
# It may happen that the Cosmo Tech API meet some issues with Keycloak without this setup.



# Configure DNS resolution on Linux (CoreDNS requires this to works properly on Kubernetes)
# Usage: configure_dns <domain_zone>
configure_dns() {
  local domain_zone_to_add_in_search="$1"
  local dns_file='/etc/resolv.conf'

  # Ensure the DNS file exists
  if [ ! -f $dns_file ]; then
    echo "error: file '$dns_file' not found, DNS will not work"
    return 1
  fi

  # Ensure the given domain zone is not empty
  if [ "$(echo $domain_zone_to_add_in_search)" = '' ]; then
    # echo "error: empty domain zone from env variable TERRAFORM_domain_zone (is terraform.tfvars file empty?)"
    echo "error: empty domain zone from script args. Usage: ./script <domain_zone>"
    return 1
  fi

  # Ensure the domain zone is not already in the search field
  if [ "$(cat $dns_file | grep -w 'search' | grep -w $domain_zone_to_add_in_search)" ]; then
    echo "info: domain zone '$domain_zone_to_add_in_search' already present in $dns_file"
    return 0
  fi

  # Ensure the search field exists to add the domain zone...
  if [ "$(cat $dns_file | grep -w 'search')" ]; then
    sed -i "s|search\(.*\)|search $domain_zone_to_add_in_search \1|" $dns_file
  else
    # ... and create it if not
    echo "info: adding search field $dns_file"
    echo "search $domain_zone_to_add_in_search" >> $dns_file
  fi

  # Ensure the domain zone has been well-added to the search field
  if [ "$(cat $dns_file | grep -w 'search' | grep -w $domain_zone_to_add_in_search)" ]; then
    echo "info: successfully added domain zone '$domain_zone_to_add_in_search' in $dns_file"
  else
    echo "error: domain zone '$domain_zone_to_add_in_search' has not been added to $dns_file"
  fi

  # sudo apt update
  # sudo apt install -y ipset ipvsadm
}

# configure_dns "$TERRAFORM_domain_zone"
configure_dns "$1"


echo ''
exit
