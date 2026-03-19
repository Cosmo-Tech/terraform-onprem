#!/bin/bash

new_kubeconfig=$1
if [ -z "$new_kubeconfig" ]; then
    echo "Usage: $0 <new_kubeconfig_file_path>"
    exit 1
fi

if [ ! -f "$new_kubeconfig" ]; then
    echo "error: file '$new_kubeconfig' not found"
    exit 1
fi


cluster_name=$(kubectl config view --kubeconfig="$new_kubeconfig" -o jsonpath='{.clusters[0].name}')

# Rename existing username & context to avoid conflicts between all the contexts due to defaults values
sed -i "s|kubernetes-admin|$cluster_name|" $new_kubeconfig
sed -i "s|$cluster_name@$cluster_name|$cluster_name|" $new_kubeconfig

# Backup the current kubeconfig
cp ~/.kube/config ~/.kube/config.save.$(date +%Y%m%d%H%M%S)

# Merge the 2 files
# KUBECONFIG accept a list of files separated with ':'
export KUBECONFIG=~/.kube/config:"$new_kubeconfig"
kubectl config view --flatten > ~/.kube/config_new

# Replace original file
mv ~/.kube/config_new ~/.kube/config
chmod 600 ~/.kube/config

echo "successfully merged kubeconfig files"

exit 0