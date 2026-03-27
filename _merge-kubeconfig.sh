#!/bin/sh

# Quickly add a new Kubectl context

kube_dir="$HOME/.kube"
kubeconfig_original="$kube_dir/config"
kubeconfig_tmp="/tmp/kubeconfig.tmp"
kubeconfig_new=$1

# Ensure script argument is not empty
if [ -z "$kubeconfig_new" ]; then
    echo "Usage: $0 <new_kubeconfig_file_path>"
    exit 1
fi

# Ensure .kube dir exists
if [ ! -d "$kube_dir" ]; then
    mkdir -p "$kube_dir"
fi

if [ ! -f "$kubeconfig_new" ]; then
    echo "error: file '$kubeconfig_new' not found"
    exit 1
fi

cluster_name="$(kubectl config view --kubeconfig="$kubeconfig_new" -o jsonpath='{.clusters[0].name}')"
echo "detected cluster name '$cluster_name' in $kubeconfig_new"

# Rename existing username & context to avoid conflicts between all the contexts due to defaults values
sed -i "/user: ./ s/\(user:\).*/\1 $cluster_name/" $kubeconfig_new
sed -i "/cluster: ./ s/\(cluster:\).*/\1 $cluster_name/" $kubeconfig_new
sed -i "/name: ./ s/\(name:\).*/\1 $cluster_name/" $kubeconfig_new


# Backup the current kubeconfig
if [ -f "$kubeconfig_original" ]; then
    cp $kubeconfig_original $kubeconfig_original.save.$(date +%Y%m%d%H%M%S)
fi

# Delete old context/cluster/user if it was already existing with same name
if [ "$(kubectl config get-users | grep -x $cluster_name)" ]; then
    kubectl config delete-user $cluster_name
fi
if [ "$(kubectl config get-clusters | grep -x $cluster_name)" ]; then
    kubectl config delete-cluster $cluster_name
fi
if [ "$(kubectl config get-contexts | grep -x $cluster_name)" ]; then
    kubectl config delete-context $cluster_name
fi


# Merge the 2 files
# KUBECONFIG accept a list of files separated with ':'
export KUBECONFIG="$kubeconfig_original":"$kubeconfig_new"
kubectl config view --flatten > $kubeconfig_tmp

# Replace original file with the tmp file
mv $kubeconfig_tmp $kubeconfig_original
chmod 600 $kubeconfig_original


if [ -z "$(kubectl config get-contexts -o name | grep -x $cluster_name)" ]; then
    error_flag='true'
    echo "error: context '$cluster_name' not added"
fi

if [ -z "$(kubectl config get-users | grep -x $cluster_name)" ]; then
    error_flag='true'
    echo "error: user '$cluster_name' not added"
fi

if [ -z "$(kubectl config get-clusters | grep -x $cluster_name)" ]; then
    error_flag='true'
    echo "error: cluster '$cluster_name' not added"
fi

if [ "$(echo $error_flag)" != 'true' ]; then
    kubectl config use-context $cluster_name
fi

exit 0
