#!/bin/sh

terraform init
terraform plan -out .terraform.plan
terraform apply .terraform.plan

exit
