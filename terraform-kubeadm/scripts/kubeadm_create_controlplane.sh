#!/bin/sh

# Install kubeadm controlplane


# Stop script if missing dependency
required_commands="kubeadm kubectl curl"
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
  local kubeadm_config='/tmp/kubeadm.config.init.yaml'
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
  if [ "$(helm --kubeconfig $kubeconfig_file -n tigera-operator list | grep -w calico)" ]; then
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

  # Wait for calico to have created its namespace
  local timeout=120
  local waited=0
  local calico_namespace='calico-system'
  echo "start waiting for namespace '$calico_namespace' to be ready"
  while [ -z "$(kubectl --kubeconfig $kubeconfig_file get namespaces | grep -w $calico_namespace)" ]; do
    if [ "$(echo $waited)" != "$(echo $timeout)" ]; then
      echo "waited $waited sec"
    else
      break
    fi

    sleep 1
    waited=$((waited+1))
  done

  # Force Calico to bind to an interface that has access to the network (unless it might use an interface that cannot reach others kubeadm nodes)
  kubectl --kubeconfig $kubeconfig_file patch installation default --type merge -p '{"spec": {"calicoNetwork": {"nodeAddressAutodetectionV4": {"firstFound": null, "canReach": "8.8.8.8"}}}}'
}


install_controlplane
install_helm
install_calico


# Execute again firewall script, because the controlplane was not the controlplane at the moment the script have runned the first time
./requirements_firewall.sh


echo ''
exit
