cluster_name  = "devops"
cluster_stage = "dev"

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
    type = "basic"
    ip   = "192.168.0.15"
    port = "22"
    user = "admin"
  }
#   host-06 = {
#     type = "highmemory"
#     ip   = "192.168.0.16"
#     port = "22"
#     user = "admin"
#   }
#   host-07 = {
#     type = "highcpu"
#     ip   = "192.168.0.17"
#     port = "22"
#     user = "admin"
#   }
}