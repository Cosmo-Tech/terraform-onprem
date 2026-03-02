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
* deploy `docker-state-storage`
    * generate Caddy password hash and store it in .env
        ```
        cosmotech_state_password="$(head -c 40 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9')" && echo '' && echo "password to save: $cosmotech_state_password" && cosmotech_state_hashed="$(echo -n "$(docker run --rm caddy:alpine caddy hash-password --plaintext $cosmotech_state_password)" | base64 -w 0)" && echo '' && echo "COSMOTECHSTATES_PASSWORD_HASH=$cosmotech_state_hashed" > .env && unset cosmotech_state_password && unset $cosmotech_state_hashed && echo 'hashed password stored in .env'
        ```
    * in `docker-compose.yaml`, replace the existing domain URL `cosmotechstates.onpremise.platform.cosmotech.com` with yours
    * run Docker
        ```
        docker compose -f docker-state-storage/docker-compose.yaml up -d
        ```
* deploy `terraform-dns-challenge-requirements`
    * tofill
* deploy `terraform-cluster`
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
* Terraform modules
    * **terraform-dns-challenge-requirements**
        * Create requirements that permit to run a DNS-01 challenge. Note: HTTP-01 challenges cannot work in a private network.
        * This is a separated module because it's useful for both `terraform-state-storage` & `terraform-cluster` modules
    * **terraform-cluster**
        * *kubeadm* = Install kubeadm on Linux hosts. This module is optional, it depends on the needs
        * *longhorn* = Storage solution
        * *metallb* = Load-balancer for on-premise Kubernetes clusters
        * *storage* = persistent storage for Kubernetes statefulsets (this module is not used directly here, it's always used in remote modules through its Github URL)
* Docker
    * **docker-state-storage**
        * Create a place to host the Terraform states files
        * A simple HTTP server will be created, and can be used from Terraform backend type "HTTP" with TLS & authentication
        * Terraform states are stored in local volume (check docker-compose.yaml file for more details)
        * This is just a quick way to have a place to store the state (any other existing HTTP server can be use)

<br>
<br>
<br>

Made with :heart: by Cosmo Tech DevOps team