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


# --- Install Controlplane
# Exit if controlplane already exists (avoid duplicating firewall rules)
kubeconfig_file='/etc/kubernetes/admin.conf'
if [ -f "$kubeconfig_file" ] && [ "$(sudo kubectl --kubeconfig $kubeconfig_file get nodes | grep -w control-plane)" ]; then
  echo 'error: controlplane already exists'
  exit
else
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16
  mkdir -p "$admin_user_home/.kube"
  sudo cp '/etc/kubernetes/admin.conf' "$admin_user_home/.kube/config"
  sudo chown "$admin_user:$admin_user" "$admin_user_home/.kube/config"
fi
# --- Install Controlplane


# --- Install Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/calico.yaml
kubectl set env daemonset/calico-node -n kube-system IP_AUTODETECTION_METHOD=interface=ens.*

# Add rule to firewall and be sure it's not duplicated
# Usage: firewall_add_rule <rule>
firewall_add_rule() {
  local rule="$*"

  # if [ ! "$(sudo nft list ruleset | grep -Fq "$rule")" ]; then
  #   sudo nft add rule $rule
  # fi

  sudo nft delete rule $rule
  sudo nft add rule $rule
}
# - allow Kubernetes API
# - allow Kubelet (Logs & Stats)
# - allow BGP (Calico between nodes)
# - allow IPIP
# - allow Calico virtual interfaces
firewall_add_rule inet filter INPUT tcp dport 6443 counter accept
firewall_add_rule inet filter INPUT tcp dport 10250 counter accept
firewall_add_rule inet filter INPUT tcp dport 179 counter accept
firewall_add_rule inet filter INPUT ip protocol ipip counter accept
firewall_add_rule inet filter INPUT iifname "cali*" counter accept
firewall_add_rule inet filter INPUT iifname "tunl0" counter accept
sudo nft list ruleset | sudo tee /etc/nftables.conf

# Reboot Calico pods to use new firewall
kubectl -n kube-system delete pod -l k8s-app=calico-node
kubectl -n kube-system delete pod -l k8s-app=calico-kube-controllers
# --- Install Calico


exit
