![Static Badge](https://img.shields.io/badge/Cosmo%20Tech-%23FFB039?style=for-the-badge)
![Static Badge](https://img.shields.io/badge/On_premise-%23BBE3F8?style=for-the-badge)

#  Kubernetes cluster

## Requirements
* [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
* situational
    * **docker-state-storage**
        * [docker](https://docs.docker.com/engine/install/) for the Caddy state storage
    * **terraform-kubeadm**
        * at least 5 working Linux hosts (must be Debian/Ubuntu, because scripts are based on [APT](https://fr.wikipedia.org/wiki/Advanced_Packaging_Tool) & [nftables](https://wiki.nftables.org/))
        * `sudo` SSH access to all the hosts
        * same sudo passwords on all the hosts (can be temporary)
        * minimal resources requirements are written at the end of this README file
    * **terraform-cluster**
        * a working [Kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/) cluster (can be installed from `terraform-kubeadm`, but is not mandatory)
        * admin access to the Kubeadm cluster

## How to
* clone current repo
    ```
    git clone https://github.com/Cosmo-Tech/terraform-onprem.git --branch <tag>
    cd terraform-onprem
    ```
* deploy `docker-state-storage`
    * generate a password for Caddy and store its hash in .env
        > :warning: Only the hash of the generated password will be stored, the password itself will not be saved. You have to store it in a safe place.
        ```
        cosmotech_state_password="$(head -c 40 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9')" && echo '' && echo "password to save: $cosmotech_state_password" && cosmotech_state_hashed="$(echo -n "$(docker run --rm caddy:alpine caddy hash-password --plaintext $cosmotech_state_password)" | base64 -w 0)" && echo '' && echo "COSMOTECHSTATES_PASSWORD_HASH=$cosmotech_state_hashed" > .env && unset cosmotech_state_password && unset $cosmotech_state_hashed && echo 'hashed password stored in .env'
        ```
    * in `docker-compose.yaml`, replace the existing domain URL `cosmotechstates.onpremise.platform.cosmotech.com` with yours
    * run Docker
        ```
        docker compose -f docker-state-storage/docker-compose.yaml up -d
        ```
    > After have setuped the DNS challenge, you can remove `tls internal` from `docker-compose.yaml` to improve security
* *(optional)* deploy `terraform-kubeadm`
    > This module allows to quickly install [Kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/) on top of existing Linux hosts (sudo SSH access is required) \
    > You can skip this step if you already have [a working Kubeadm cluster](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)
    * fill `terraform-kubeadm/terraform.tfvars` variables according to your needs
    * *(optional)* it's recommended to have a working SSH agent
        > This Terraform module is using remote-exec provisionners, which is based on SSH. \
        ```ssd-add -l```
    * run pre-configured script
        > :pencil2: comment/uncomment the `terraform apply` line at the end to get a plan without deploy anything
        * Linux
            ```
            ./_run-terraform.sh
            ```
    * install cluster context locally
        * once finished, the kubeconfig file of the new cluster might be ready in /tmp/kubeconfig_xxxxx.yaml
        * you can add it to your existing kubeconfig file by running this script:
            ```
            ./_merge-kubeconfig.sh </tmp/kubeconfig_xxxxx.yaml>
            ```
* if you didn't used `terraform-kubeadm`
    > *terraform-kubeadm* is automatically running these scripts
    * configure required firewall rules on all the hosts
        > Kubernetes, Calico, Longhorn etc.. rely on host firewall to work properly
        * run script on all the hosts of the cluster
            > you can also manually configure firewalls, all rules are explicits in the script \
            > :warning: the control-plane and nodes hosts doesn't need the exact same firewall rules
            ```
            ./terraform-kubeadm/scripts/requirements_firewall.sh
            ```
    * install Longhorn requirements on the host
        > Longhorn (= the system used to have persistence on Kubernetes) needs to have some specific packages installed directly on the hosts.
        * run script on all the hosts of the cluster
            > you can also manually install the Longhorn requirements by following the [official documentation](https://longhorn.io/docs/latest/deploy/install/#installation-requirements)
            ```
            ./terraform-kubeadm/scripts/requirements_longhorn.sh
            ```
* deploy `terraform-cluster`
    * fill `terraform-cluster/terraform.tfvars` variables according to your needs
    * run pre-configured script
        > :pencil2: comment/uncomment the `terraform apply` line at the end to get a plan without deploy anything
        * Linux
            ```
            ./_run-terraform.sh
            ```
* situational:
    * Add DNS records to your DNS zone (3 records: 1x cluster, 1x specific Superset, 1x state storage)
        > If DNS records need to be registered in a local DNS, manual creation is required (because Terraform cannot handle it). \
        > For example, in Cosmo Tech case, the required records will be: \
        > `<cluster_name>.onpremise.platform.cosmotech.com` \
        > `superset-<cluster_nale>.onpremise.platform.cosmotech.com` \
        > `cosmotechstates.onpremise.platform.cosmotech.com`

## Known errors
* Ghost volumes on Longhorn
    > * Connect directly to control-plane host (SSH or direct access), with sudo access
    > * Be sure to have `etcd-client` installed
    > * List volumes to get exacts names
    >     ```
    >     sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get /registry/longhorn.io/volumes/ --prefix --keys-only
    >     ```
    > * Delete the volume (copy/paste the exact name of the volume from the previous command) \
         > :warning: Data hosted on the volume will be destroyed with the volume. Be sure to have a copy before operates.
    >     ```
    >     sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key del /registry/longhorn.io/volumes/longhorn-system/VOLUME_NAME
    >     ```

## Developpers
* Terraform modules
    * **terraform-cluster**
        * *longhorn* = Storage solution
        * *metallb* = Load-balancer for on-premise Kubernetes clusters
        * *dns_challenges_requirements* =
            * create the DNS provider requirements to run cert-manager with DNS-01 challenge (HTTP-01 challenges might not work in local networks)
            * store relevant informations in a Kubernetes secrets `dns-challenge`
        * *storage* = persistent storage for Kubernetes statefulsets (this module is not used directly here, it's always used in remote modules through its Github URL)
    * **terraform-kubeadm**
        * install [Kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) on top of existing Linux hosts
        * install Helm on the controlplane host
        * install Calico on the Kubeadm cluster
        * configure firewall (with [nftables](https://wiki.nftables.org/)) -> it creates a dedicated nftables chain "COSMO-KUBE"
* Docker
    * **docker-state-storage**
        * Create a place to host the Terraform states files
        * A simple HTTP server will be created, and can be used from Terraform backend type "HTTP" with TLS & authentication
        * Terraform states are stored in local volume (check docker-compose.yaml file for more details)
        * This is just a quick way to have a place to store the state (any other existing HTTP server can be use)

## Minimal resources requirements
> Note: these requirements are minimals, and can be differents depending on your situation.

|Host|CPU|Memory|Usage|
|----|---|------|-----|
|States storage|1|1 Go|Store Terraform & Babylon states files|
|Kubeadm control-plane|[check requirements here](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)|[check requirements here](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)|Kubeadm main host|
|Kubeadm node db|16|16 Go|Host Cosmo Tech platform databases|
|Kubeadm node services|16|16 Go|Host Cosmo Tech platform services required by the API|
|Kubeadm node monitoring|4|8 Go|Host Cosmo Tech platform monitoring|
|Kubeadm node basic|16|16 Go|Run Cosmo Tech platform simulations|

<br>
<br>
<br>

Made with :heart: by Cosmo Tech DevOps team