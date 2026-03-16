#!/bin/sh


rm -f terraform.tfstate*

terraform init
terraform plan -out .terraform.plan
terraform apply .terraform.plan

exit
