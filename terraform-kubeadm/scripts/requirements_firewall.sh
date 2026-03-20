#!/bin/sh


# Stop script if missing dependency
required_commands="nft"
for command in $required_commands; do
    if [ -z "$(command -v $command)" ]; then
        echo "error: required command not found: $command"
        exit 1
    fi
done


# Stop script if not sudo
if [ "$(id -u)" != "0" ]; then
  echo "sudo is required"
  exit 1
fi


# Get the IP address used to access the LAN. Example: '192.168.0.11'
lan_ip_address="$(hostname -I | cut -d ' ' -f 1)"

# Get the IP address with its mask. Example: '192.168.0.11/24'
lan_ip_cidr="$(ip a | grep -w $lan_ip_address | head -n 1 | sed "s|.*\($lan_ip_address/[0-9]*\).*|\1|")"


# Detect if currently running on the machine that hosts the controlplane, or not (return 'true' or 'false')
# Usage: am_i_the_controlplane
am_i_the_controlplane() {
  if [ -d "/etc/kubernetes/manifests" ] && [ -f "/etc/kubernetes/manifests/kube-apiserver.yaml" ]; then
    echo "true"
  elif [ -f "$HOME/.kube/config" ] || [ -f "/etc/kubernetes/admin.conf" ]; then
    # Kubeconfig file exists, checking if it works
    KUBECONFIG_PATH=${KUBECONFIG:-$HOME/.kube/config}
    [ ! -f "$KUBECONFIG_PATH" ] && KUBECONFIG_PATH="/etc/kubernetes/admin.conf"

    ROLE=$(kubectl --kubeconfig "$KUBECONFIG_PATH" get node $(hostname) -o custom-columns=ROLE:.metadata.labels."node-role\.kubernetes\.io/control-plane" --no-headers 2>/dev/null)
    [[ "$ROLE" != "<none>" && "$ROLE" != "" ]] && echo "true" || echo "false"
  else
    # No manifest, no kubeconfig file => means it's a node
    echo "false"
  fi
}


# Add nftables custom chain
# Usage: add_nft_chain <chain name>
add_nft_chain() {
  local nftables_chain=$1

  # Ensure nftables table exists
  sudo nft add table inet filter

  # Create a clean nftables chain dedicated for Kube:
  # -> delete chain relation -> it allows to delete the dedicated kube chain -> it allows to recreate a clean chain
  local nftables_rule_jump_id="$(sudo nft -a list chain inet filter INPUT | grep -w "jump $nftables_chain" | awk '/handle [0-9]+/ {print $NF}')"
  if [ -n "$nftables_rule_jump_id" ]; then
    sudo nft delete rule inet filter INPUT handle $nftables_rule_jump_id
  fi
  sudo nft add chain inet filter "$nftables_chain"
  sudo nft flush chain inet filter "$nftables_chain"
  sudo nft delete chain inet filter "$nftables_chain"
  sudo nft add chain inet filter "$nftables_chain"

  # Create a clean rule to jump original INPUT chain to the kube dedicated chain
  if [ -z "$(sudo nft list chain inet filter INPUT | grep -w "jump $nftables_chain")" ]; then
    sudo nft add rule inet filter INPUT jump "$nftables_chain"
  fi
}


# Add nftables rules that are the same between controlplane & nodes
# Usage: add_rules_common <chain name>
add_rules_common() {
  local nftables_chain=$1

  # - allow localhost
  # - allow Calico interfaces
  # - allow IPIP protocol (for Calico)
  # - allow port 179 (BGP, for Calico)
  # - allow port 5473 (Typha, for Calico)
  # - allow port 10250 (Kubelet API)
  # - allow port 3260 (iSCSI, for Longhorn)
  # - allow ports 9500-9150 (multiple Longhorn services)
  # - allow all Kubeadm nodes IP (Longhorn will need it)
  sudo nft add rule inet filter "$nftables_chain" iifname "lo" counter accept
  sudo nft add rule inet filter "$nftables_chain" iifname "cali*" counter accept
  sudo nft add rule inet filter "$nftables_chain" iifname "tunl0" counter accept
  sudo nft add rule inet filter "$nftables_chain" ip protocol ipip counter accept
  sudo nft add rule inet filter "$nftables_chain" tcp dport 179 counter accept
  sudo nft add rule inet filter "$nftables_chain" tcp dport 5473 counter accept
  sudo nft add rule inet filter "$nftables_chain" tcp dport 10250 counter accept
  # sudo nft add rule inet filter "$nftables_chain" tcp dport 3260 counter accept
  # sudo nft add rule inet filter "$nftables_chain" tcp dport 9500-9510 counter accept
  sudo nft add rule inet filter "$nftables_chain" ip saddr "$lan_ip_cidr" counter accept
}


# Add nftables rules to make a controlplane working
# Usage: add_rules_if_controlplane <chain name>
add_rules_if_controlplane() {
  local nftables_chain=$1

  # - allow port 6443 (Kubernetes API)
  sudo nft add rule inet filter "$nftables_chain" tcp dport 6443 counter accept
}


# Add a chain for common rules
add_nft_chain 'INPUT-COSMO-KUBE'
add_rules_common 'INPUT-COSMO-KUBE'


# Add dedicated chain for specific controlplane rules
if [ "$(am_i_the_controlplane)" = 'true' ]; then
  add_nft_chain 'INPUT-COSMO-KUBE-CONTROLPLANE'
  add_rules_if_controlplane 'INPUT-COSMO-KUBE-CONTROLPLANE'
fi


# Save nftables ruleset
sudo nft list ruleset > /etc/nftables.conf
sudo systemctl enable nftables


echo ''
exit
