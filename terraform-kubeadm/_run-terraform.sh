#!/bin/sh


rm -rf terraform.tfstate*
rm -rf .terraform*

terraform init
terraform plan -out .terraform.plan
terraform apply .terraform.plan

echo 'kubeconfig file saved in /tmp'
echo ''
cat /tmp/kubeconfig_*


exit
