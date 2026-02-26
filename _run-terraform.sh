#!/bin/sh

# Script to run terraform modules
# Usage :
# - ./script.sh


# Stop script if missing dependency
required_commands="terraform"
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

    cat $file | grep '=' | grep -w $variable | sed 's|.*"\(.*\)".*|\1|' | head -n 1
}
cluster_name="$(get_var_value terraform-cluster/terraform.tfvars cluster_name)"
cluster_stage="$(get_var_value terraform-cluster/terraform.tfvars cluster_stage)"
cluster_region="$(get_var_value terraform-cluster/terraform.tfvars cluster_region)"

# state_storage_name="$(get_var_value terraform-state-storage/main.tf name)"



# Clear old data
rm -rf terraform-cluster/.terraform*
rm -rf terraform-cluster/terraform.tfstate*


# Deploy
terraform -chdir=terraform-cluster init
# terraform -chdir=terraform-cluster init -upgrade -reconfigure -backend-config="key=tfstate-cluster-kob-$cluster_stage-$cluster_name"
terraform -chdir=terraform-cluster plan -out .terraform.plan
terraform -chdir=terraform-cluster apply .terraform.plan


exit 0
