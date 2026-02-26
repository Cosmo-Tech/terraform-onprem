![Static Badge](https://img.shields.io/badge/Cosmo%20Tech-%23FFB039?style=for-the-badge)
![Static Badge](https://img.shields.io/badge/On_premise-%23BBE3F8?style=for-the-badge)

#  Kubernetes cluster

## Requirements
* working Linux hosts
* [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
    > If using Windows, Terraform must be accessible from PATH

## How to
* clone current repo
    ```
    git clone https://github.com/Cosmo-Tech/terraform-onprem.git --branch <tag>
    cd terraform-onprem
    ```
* deploy
    * fill `terraform-cluster/terraform.tfvars` variables according to your needs
        > :pencil2: you can change default Kubernetes nodes configuration from `terraform-cluster/terraform.auto.tfvars`
    * run pre-configured script
        > :pencil2: comment/uncomment the `terraform apply` line at the end to get a plan without deploy anything
        * Linux
            ```
            ./_run-terraform.sh
            ```
        * Windows
            ```
            ./_run-terraform.ps1
            ```

## Known errors
* No known error for now !

## Developpers
* modules
    * **terraform-state-storage**
        * todo
    * **terraform-cluster**
        * *longhorn* = Storage solution
        * *metallb* = Load-balancer for on-premise Kubernetes clusters
        * *storage* = persistent storage for Kubernetes statefulsets (this module is not used directly here, it's always used in remote modules through its Github URL)

<br>
<br>
<br>

Made with :heart: by Cosmo Tech DevOps team