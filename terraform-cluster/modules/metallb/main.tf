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
  # Convert IPv4 to a 32-bit integer, add the range, convert back.
  # This safely handles overflow across octets (e.g. x.x.x.252 + 6 → x.x.y.2)
  ip_parts  = split(".", var.cluster_ip)
  ip_octet0 = tonumber(local.ip_parts[0])
  ip_octet1 = tonumber(local.ip_parts[1])
  ip_octet2 = tonumber(local.ip_parts[2])
  ip_octet3 = tonumber(local.ip_parts[3])

  ip_start_int = ((local.ip_octet0 * 256 + local.ip_octet1) * 256 + local.ip_octet2) * 256 + local.ip_octet3
  ip_end_int   = local.ip_start_int + var.ip_range_size - 1

  ip_end_octet3 = local.ip_end_int % 256
  ip_end_tmp2   = floor(local.ip_end_int / 256)
  ip_end_octet2 = local.ip_end_tmp2 % 256
  ip_end_tmp1   = floor(local.ip_end_tmp2 / 256)
  ip_end_octet1 = local.ip_end_tmp1 % 256
  ip_end_octet0 = floor(local.ip_end_tmp1 / 256)

  cluster_ip_end = "${local.ip_end_octet0}.${local.ip_end_octet1}.${local.ip_end_octet2}.${local.ip_end_octet3}"
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