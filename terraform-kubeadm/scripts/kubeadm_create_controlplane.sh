#!/bin/sh

# Install kubeadm controlplane


# Stop script if missing dependency
required_commands="kubeadm kubectl nft"
for command in $required_commands; do
    if [ -z "$(command -v $command)" ]; then
        echo "error: required command not found: $command"
        exit 1
    fi
done


# Stop script if not sudo
if [ "$(id -u)" != "0" ]; then
  echo "sudo is required"
  exit
fi


admin_user="$(logname)"
admin_user_home="$(getent passwd $admin_user | cut -d: -f6)"


# --- Install controlplane
# Exit if controlplane already exists (avoid duplicating firewall rules)
kubeconfig_file='/etc/kubernetes/admin.conf'
if [ -f "$kubeconfig_file" ] || [ "$(sudo kubectl --kubeconfig $kubeconfig_file get nodes | grep -w control-plane)" ]; then
  echo 'error: controlplane already exists'
  exit
fi

# Init controlplane
kubeadm_config='/tmp/kubeadm.config.init.yaml'
if [ -f "$kubeadm_config" ]; then
  echo "info: found kubeadm init config file $kubeadm_config"
  sudo kubeadm init --config "$kubeadm_config"
else
  echo "error: missing kubeadm init config file $kubeadm_config"
  exit
fi

# Add kubeconfig to admin user
mkdir -p "$admin_user_home/.kube"
sudo cp '/etc/kubernetes/admin.conf' "$admin_user_home/.kube/config"
sudo chown "$admin_user:$admin_user" "$admin_user_home/.kube/config"  
# --- Install controlplane


# --- Install Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/calico.yaml
kubectl set env daemonset/calico-node -n kube-system IP_AUTODETECTION_METHOD=interface=ens.*
# --- Install Calico


# --- Configure host firewall
nftables_chain='COSMO-KUBE'

# Ensure nftables table exists
sudo nft add table inet filter

# Create a clean nftables chain dedicated for Kube:
# -> delete chain relation -> it allows to delete the dedicated kube chain -> it allows to recreate a clean chain
nftables_rule_jump_id="$(sudo nft -a list chain inet filter INPUT | grep -w "jump $nftables_chain" | awk '/handle [0-9]+/ {print $NF}')"
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

# - allow Kubernetes API
# - allow Kubelet (Logs & Stats)
# - allow BGP (Calico between nodes)
# - allow IPIP
# - allow Calico virtual interfaces
sudo nft add rule inet filter "$nftables_chain" tcp dport 6443 counter accept
sudo nft add rule inet filter "$nftables_chain" tcp dport 10250 counter accept
sudo nft add rule inet filter "$nftables_chain" tcp dport 179 counter accept
sudo nft add rule inet filter "$nftables_chain" ip protocol ipip counter accept
sudo nft add rule inet filter "$nftables_chain" iifname "cali*" counter accept
sudo nft add rule inet filter "$nftables_chain" iifname "tunl0" counter accept
sudo nft add rule inet filter "$nftables_chain" iifname "lo" counter accept

# Save nftables ruleset
sudo nft list ruleset > /etc/nftables.conf
# --- Configure host firewall


exit
