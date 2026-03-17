#!/bin/sh


rm -rf terraform.tfstate*
rm -rf .terraform*

terraform init
terraform plan -out .terraform.plan
terraform apply .terraform.plan

exit
