#!/bin/sh

# Install kubeadm controlplane


# Stop script if missing dependency
required_commands="kubeadm kubectl nft curl"
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


admin_user="$(logname)"
admin_user_home="$(getent passwd $admin_user | cut -d: -f6)"

kubeconfig_file='/etc/kubernetes/admin.conf'


# Add kubeconfig to admin user
# Usage: copy_kubeconfig_file_to_user_home
copy_kubeconfig_file_to_user_home() {
  mkdir -p "$admin_user_home/.kube"
  sudo cp -f "$kubeconfig_file" "$admin_user_home/.kube/config"
  sudo chown "$admin_user:$admin_user" "$admin_user_home/.kube/config"
}


# Install controlplane
# Usage: install_controlplane
install_controlplane() {

  # Exit if controlplane already exists (avoid duplicating firewall rules)
  if [ -f "$kubeconfig_file" ] || [ "$(sudo kubectl --kubeconfig $kubeconfig_file get nodes | grep -w control-plane)" ]; then
    echo 'info: controlplane already exists, skipping'

    # Controlplane already exists, it means we can copy/paste the existing kubeconfig file to user home
    copy_kubeconfig_file_to_user_home
    exit 0
  fi

  # Init controlplane
  kubeadm_config='/tmp/kubeadm.config.init.yaml'
  if [ -f "$kubeadm_config" ]; then
    echo "info: found kubeadm init config file $kubeadm_config"
    sudo kubeadm init --config "$kubeadm_config"
  else
    echo "error: missing kubeadm init config file $kubeadm_config"
    exit 0
  fi

  # If the script is running until here, it's time to add the kubeconfig file to user home
  copy_kubeconfig_file_to_user_home
}


# Install helm
# Usage: install_helm
install_helm() {
  sudo apt-get install curl gpg apt-transport-https --yes
  curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
  sudo apt-get update
  sudo apt-get install helm
}


# Install Calico
# Usage: install_calico
install_calico() {
  if [ "$(helm -n tigera-operator list | grep -w calico)" ]; then
    echo 'info: calico already installed, skipping'
    exit 0
  fi

  helm --kubeconfig $kubeconfig_file repo add projectcalico https://docs.tigera.io/calico/charts
  helm --kubeconfig $kubeconfig_file repo update
  helm --kubeconfig $kubeconfig_file install calico projectcalico/tigera-operator \
    --namespace tigera-operator \
    --create-namespace \
    --set installation.calicoNetwork.ipPools[0].cidr=192.168.0.0/16 \
    --set installation.calicoNetwork.ipPools[0].encapsulation=IPIP

  # Wait to ensure CRD are created
  sleep 10
  kubectl --kubeconfig $kubeconfig_file set env daemonset/calico-node -n calico-system IP_AUTODETECTION_METHOD=can-reach=8.8.8.8
}


# Configure firewall
# Usage: configure_firewall
configure_firewall() {
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
  sudo nft add rule inet filter "$nftables_chain" iifname "lo" counter accept
  sudo nft add rule inet filter "$nftables_chain" tcp dport 6443 counter accept
  sudo nft add rule inet filter "$nftables_chain" tcp dport 10250 counter accept
  sudo nft add rule inet filter "$nftables_chain" tcp dport 179 counter accept
  sudo nft add rule inet filter "$nftables_chain" ip protocol ipip counter accept
  sudo nft add rule inet filter "$nftables_chain" iifname "cali*" counter accept
  sudo nft add rule inet filter "$nftables_chain" iifname "tunl0" counter accept

  # Save nftables ruleset
  sudo nft list ruleset > /etc/nftables.conf
}


install_controlplane
install_helm
configure_firewall
install_calico



exit
