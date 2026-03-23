#!/bin/sh

# Script to run terraform modules
# Usage :
# - ./script.sh


# Stop script if missing dependency
required_commands="terraform curl"
for command in $required_commands; do
    if [ -z "$(command -v $command)" ]; then
        echo "error: required command not found: \e[91m$command\e[97m"
        exit 1
    fi
done


existing_module_list="$(ls -d */ | cut -f1 -d'/' | grep -w terraform)"
if [ -z "$COSMO_TF_MODULE_TO_RUN" ] || [ -z "$(echo $existing_module_list | grep $COSMO_TF_MODULE_TO_RUN)" ]; then
    echo ''
    echo "\e[97merror: missing Terraform module target from \e[91mCOSMO_TF_MODULE_TO_RUN\e[97m. Please copy/paste one of the following:"
    for module in $existing_module_list; do
        echo "  export COSMO_TF_MODULE_TO_RUN=$module"
    done
    exit
fi


echo "running module $COSMO_TF_MODULE_TO_RUN"


# Dynamically copy variables to the running module (allow avoid the user needs to fill a different file for each module)
rm -f "$COSMO_TF_MODULE_TO_RUN/terraform.tfvars"
cp -f 'terraform.tfvars' "$COSMO_TF_MODULE_TO_RUN/"


# Get value of a variable declared in a given file from this pattern: variable = value
# Usage: get_var_value <file> <variable>
get_var_value() {
    local file=$1
    local variable=$2

    cat $file | grep '=' | grep -w $variable | sed '/.*#.*/d' | sed 's|.*=.*"\(.*\)".*|\1|' | head -n 1
}
cluster_name="$(get_var_value $COSMO_TF_MODULE_TO_RUN/terraform.tfvars cluster_name)"
cluster_stage="$(get_var_value $COSMO_TF_MODULE_TO_RUN/terraform.tfvars cluster_stage)"
cluster_region="$(get_var_value $COSMO_TF_MODULE_TO_RUN/terraform.tfvars cluster_region)"
state_host="$(get_var_value $COSMO_TF_MODULE_TO_RUN/terraform.tfvars state_host)"

override_naming_convention="$(get_var_value $COSMO_TF_MODULE_TO_RUN/terraform.tfvars override_naming_convention)"
if [ "$(echo $override_naming_convention)" = 'true' ]; then
    state_file_name="tfstate-cluster-kob-$cluster_name"
else
    state_file_name="tfstate-cluster-kob-$cluster_stage-$cluster_name-$COSMO_TF_MODULE_TO_RUN"
fi
state_url="$state_host/$state_file_name"


# Clear old data
rm -rf $COSMO_TF_MODULE_TO_RUN/.terraform*
rm -rf $COSMO_TF_MODULE_TO_RUN/terraform.tfstate*


echo ''
if [ -z "$TF_HTTP_USERNAME" ] || [ -z "$TF_HTTP_PASSWORD" ]; then
    echo "error: empty TF_HTTP_USERNAME or TF_HTTP_PASSWORD (required for backend authentication)"
    echo "  export TF_HTTP_USERNAME="
    echo "  export TF_HTTP_PASSWORD="
    exit
else
    echo "found TF_HTTP_USERNAME & TF_HTTP_PASSWORD"
fi


# Ensure a storage service exist to store the states and ask to create it if doesn't exist
state_storage_status="$(curl -sIk -m 3 $state_host -u "$TF_HTTP_USERNAME:$TF_HTTP_PASSWORD" | head -n 1 | cut -d ' ' -f 2 | cut -c 1)"
if [ -z "$(echo $state_storage_status)" ]; then
    echo "error: $state_host not reachable"
    exit
fi
# Ensure HTTP code is 2xx 
if [ "$(echo $state_storage_status)" != '2' ]; then
    echo ''
    echo "error: could not reach states storage: \e[91m$state_host\e[0m (can be either a network or authentication issue)"
    echo 'you can either:'
    echo '  - configure an existing HTTP server where data are safely stored in $COSMO_TF_MODULE_TO_RUN/providers.tf'
    echo '  - install the pre-configured Docker container on a dedicated host (copy/paste following commands to do so)'
    echo '      cosmotech_state_password="$(head -c 40 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9')" && echo '' && echo "password to save: $cosmotech_state_password" && cosmotech_state_hashed="$(echo -n "$(docker run --rm caddy:alpine caddy hash-password --plaintext $cosmotech_state_password)" | base64 -w 0)" && echo '' && echo "COSMOTECHSTATES_PASSWORD_HASH=$cosmotech_state_hashed" > .env && unset cosmotech_state_password && unset $cosmotech_state_hashed && echo 'hashed password stored in .env''
    echo '      docker compose -f docker-state-storage/docker-compose.yaml up -d'
    exit
else
    echo "found $state_host"
fi


# Deploy
terraform -chdir="$COSMO_TF_MODULE_TO_RUN" init -upgrade -reconfigure -backend-config="address=$state_url" -backend-config="lock_address=$state_url/lock" -backend-config="unlock_address=$state_url/lock"
terraform -chdir="$COSMO_TF_MODULE_TO_RUN" plan -lock=false -out .terraform.plan


option_apply='--apply'
if [ "$(echo $1)" = "$option_apply" ]; then
    terraform -chdir="$COSMO_TF_MODULE_TO_RUN" apply -lock=false .terraform.plan
else
    echo ''
    echo "\e[97mTerraform plan can be applied with:"
    echo "  $0 $option_apply"
fi


# Just a message to display after have runned terraform-hosts
if [ "$COSMO_TF_MODULE_TO_RUN" = 'terraform-hosts' ] && [ "$(ls /tmp/ | grep kubeconfig_)" ]; then
    echo ''
    echo 'Kubeconfig file is available at /tmp/'
    echo 'you can merge it with your existing kubeconfig file with:'
    echo '  ./_merge-kubeconfig.sh /tmp/FILENAME'
fi


exit 0
