cluster_name  = "devops2"
cluster_stage = "dev"
domain_zone   = "onpremise.platform.cosmotech.com"

# Override the default naming convention
#  - false => "kob-<cluster_stage>-<cluster_name>"
#  - true  => cluster_name = the exact name that will be used
override_naming_convention = "false"

# State host can be DNS record, IP address, and must start with http:// or https://
# state_host = "http://192.168.x.x"
state_host = "https://cosmotechstates.onpremise.platform.cosmotech.com"

# DNS challenge provider where the cluster record is hosted
dns_challenge_provider = "azure"

# This IP address must not be affected to anything (including any nodes of the cluster). It will be used to serve the HTTPS endpoints of the Cosmo Tech platform (and it must be mapped to the DNS records of the Cosmo Tech platform)
ip_address_for_web_services = "192.168.0.101"
ip_address_for_superset     = "192.168.0.102"

# How to fill the 'hosts' map below
# "Host" means the Linux server on which the Kubernetes node will be install (it can be VM, bare-metal etc...). The only requirements are: Debian-based host + root SSH access
# - Edit IP addresses below according to your situation (they will be used to connect through SSH)
# - You can add/remove as many host as you want (/!\ only one controlplane). Keep in mind that the Cosmo Platform will not works without at least one of each: controlplane, db, services, monitoring, basic 
hosts = {
  host-01 = {
    type = "controlplane"
    ip   = "192.168.0.11"
    port = "22"
    user = "admin"
  }
  host-02 = {
    type = "db"
    ip   = "192.168.0.12"
    port = "22"
    user = "admin"
  }
  host-03 = {
    type = "services"
    ip   = "192.168.0.13"
    port = "22"
    user = "admin"
  }
  host-04 = {
    type = "monitoring"
    ip   = "192.168.0.14"
    port = "22"
    user = "admin"
  }
  host-05 = {
    type = "compute"
    size = "basic"
    ip   = "192.168.0.15"
    port = "22"
    user = "admin"
  }
  #   host-06 = {
  #     type = "compute"
  #     size = "highmemory"
  #     ip   = "192.168.0.16"
  #     port = "22"
  #     user = "admin"
  #   }
  #   host-07 = {
  #     type = "compute"
  #     size = "highcpu"
  #     ip   = "192.168.0.17"
  #     port = "22"
  #     user = "admin"
  #   }
}
