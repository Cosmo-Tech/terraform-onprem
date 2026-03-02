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


# Get value of a variable declared in a given file from this pattern: variable = value
# Usage: get_var_value <file> <variable>
get_var_value() {
    local file=$1
    local variable=$2

    cat $file | grep '=' | grep -w $variable | sed '/.*#.*/d' | sed 's|.*=.*"\(.*\)".*|\1|' | head -n 1
}
cluster_name="$(get_var_value terraform-cluster/terraform.tfvars cluster_name)"
cluster_stage="$(get_var_value terraform-cluster/terraform.tfvars cluster_stage)"
cluster_region="$(get_var_value terraform-cluster/terraform.tfvars cluster_region)"

state_host="$(get_var_value terraform-cluster/terraform.tfvars state_host)"
state_file_name="tfstate-cluster-kob-$cluster_stage-$cluster_name"
state_url="$state_host/$state_file_name"

# dns_challenge_provider="$(get_var_value terraform-cluster/terraform.tfvars dns_challenge_provider)"
# echo $dns_challenge_provider


# Clear old data
rm -rf terraform-cluster/.terraform*
rm -rf terraform-cluster/terraform.tfstate*


if [ -z $TF_HTTP_USERNAME ] || [ -z $TF_HTTP_PASSWORD ]; then
    echo "error: empty TF_HTTP_USERNAME or TF_HTTP_PASSWORD"
    echo "  export TF_HTTP_USERNAME="
    echo "  export TF_HTTP_PASSWORD="
    exit
fi


# Ensure a storage service exist to store the states and ask to create it if doesn't exist
state_storage_status="$(curl -sI $state_host -u "$TF_HTTP_USERNAME:$TF_HTTP_PASSWORD" | head -n 1 | cut -d ' ' -f 2 | cut -c 1)"
if [ "$(echo $state_storage_status)" != '2' ]; then
    echo ''
    echo "error: storage to host states not found: \e[91m$state_host\e[0m"
    echo 'you can either:'
    echo '  - configure an existing HTTP server where data are safely stored in terraform-cluster/providers.tf'
    echo '  - install the pre-configured Docker container on a dedicated host (copy/paste following commands to do so)'
    echo '      cosmotech_state_password="$(head -c 40 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9')" && echo '' && echo "password to save: $cosmotech_state_password" && cosmotech_state_hashed="$(echo -n "$(docker run --rm caddy:alpine caddy hash-password --plaintext $cosmotech_state_password)" | base64 -w 0)" && echo '' && echo "COSMOTECHSTATES_PASSWORD_HASH=$cosmotech_state_hashed" > .env && unset cosmotech_state_password && unset $cosmotech_state_hashed && echo 'hashed password stored in .env''
    echo '      docker compose -f docker-state-storage/docker-compose.yaml up -d'
    exit
else
    echo "found $state_host"
fi


# Deploy
terraform -chdir=terraform-cluster init -upgrade -reconfigure -backend-config="address=$state_url" -backend-config="lock_address=$state_url/lock" -backend-config="unlock_address=$state_url/lock"
terraform -chdir=terraform-cluster plan -lock=false -out .terraform.plan
# terraform -chdir=terraform-cluster apply -lock=false .terraform.plan


exit 0
