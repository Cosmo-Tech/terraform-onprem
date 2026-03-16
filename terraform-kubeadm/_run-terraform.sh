#!/bin/sh


rm -f terraform.tfstate*
rm -f .terraform*

terraform init
terraform plan -out .terraform.plan
terraform apply .terraform.plan

exit
