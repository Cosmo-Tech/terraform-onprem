terraform {
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1.3"
    }
  }
}

# locals {
#   # Get the IP from the existing nodes
#   cluster_ip = flatten([
#     for node in data.kubernetes_nodes.all_nodes.nodes : [
#       for addr in node.status[0].addresses : addr.address if addr.type == "InternalIP"
#     ]
#   ])[0]
# }

# data "kubernetes_nodes" "all_nodes" {}

resource "helm_release" "metallb" {
  name       = "metallb"
  namespace  = "metallb-system"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  version    = "0.15.3"

  create_namespace = true
  atomic           = false
  timeout          = 900
  cleanup_on_fail  = false
  wait             = true
  wait_for_jobs    = true

  values = [
    file("${path.module}/values.yaml")
  ]
}

locals {
  # Split the cluster IP into octets and compute the last IP of the range
  ip_parts       = split(".", var.cluster_ip)
  last_octet     = tonumber(local.ip_parts[3])
  range_end      = local.last_octet + var.ip_range_size - 1
  cluster_ip_end = "${local.ip_parts[0]}.${local.ip_parts[1]}.${local.ip_parts[2]}.${local.range_end}"
}

data "template_file" "ip_pool" {
  template = file("${path.module}/kube_objects/ip-pool.yaml")
  vars = {
    cluster_ip     = var.cluster_ip
    cluster_ip_end = local.cluster_ip_end
  }
}

resource "kubectl_manifest" "ip_pool" {
  yaml_body = data.template_file.ip_pool.rendered

  depends_on = [
    helm_release.metallb
  ]
}