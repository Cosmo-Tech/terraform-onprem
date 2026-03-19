#!/bin/bash

NEW_KUBECONFIG=$1
if [ -z "$NEW_KUBECONFIG" ]; then
    echo "Usage: $0 <new_kubeconfig_file_path>"
    exit 1
fi

if [ ! -f "$NEW_KUBECONFIG" ]; then
    echo "error: file '$NEW_KUBECONFIG' not found"
    exit 1
fi

# Backup the current kubeconfig
cp ~/.kube/config ~/.kube/config.save.$(date +%Y%m%d%H%M%S)

# Merge the 2 files
# KUBECONFIG accept a list of files separated with ':'
export KUBECONFIG=~/.kube/config:"$NEW_KUBECONFIG"
kubectl config view --flatten > ~/.kube/config_new

# Replace original file
mv ~/.kube/config_new ~/.kube/config
chmod 600 ~/.kube/config

echo "successfully merged kubeconfig files"


exit
