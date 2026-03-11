#!/bin/sh

# This script install a Kubeadm control-plane


# Stop script if not sudo
if [ "$(id -u)" != "0" ]; then
  echo "sudo is required"
  exit
fi


admin_user="$(logname)"
admin_user_home="$(getent passwd $admin_user | cut -d: -f6)"


./helpers/host.sh


install_controlplane() {
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16

    mkdir -p $admin_user_home/.kube
    sudo cp -i /etc/kubernetes/admin.conf $admin_user_home/.kube/config
    sudo chown $admin_user:$admin_user $admin_user_home/.kube/config

    kubectl get nodes
}
install_controlplane


# # --- Init cluster
# sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# mkdir -p $HOME/.kube
# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
# sudo chown $(id -u):$(id -g) $HOME/.kube/config
# # --- Init cluster


# # --- Verification
# kubectl get nodes
# # --- Verification


# # --- Install Calico
# kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

# kubectl set env daemonset/calico-node -n kube-system IP_AUTODETECTION_METHOD=interface=ens.*

# # Firewall:
# # - allow Kubernetes API
# # - allow Kubelet (Logs & Stats)
# # - allow BGP (Calico between nodes)
# # - allow IPIP
# # - allow Calico virtual interfaces
# sudo nft add rule inet filter INPUT tcp dport 6443 counter accept
# sudo nft add rule inet filter INPUT tcp dport 10250 counter accept 
# sudo nft add rule inet filter INPUT tcp dport 179 counter accept
# sudo nft add rule inet filter INPUT ip protocol ipip counter accept
# sudo nft add rule inet filter INPUT iifname "cali*" counter accept
# sudo nft add rule inet filter INPUT iifname "tunl0" counter accept
# sudo nft list ruleset | sudo tee /etc/nftables.conf

# # Reboot Calico pods to use new firewall
# kubectl delete pod -n kube-system -l k8s-app=calico-node
# kubectl delete pod -n kube-system -l k8s-app=calico-kube-controllers
# # --- Install Calico


exit
