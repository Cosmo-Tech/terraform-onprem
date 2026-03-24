locals {
  node_ip_to_name = {
    for node in data.kubernetes_nodes.all_nodes.nodes :
    flatten([
      for addr in node.status[0].addresses : addr.address if addr.type == "InternalIP"
    ])[0] => node.metadata[0].name
  }
}


data "kubernetes_nodes" "all_nodes" {}


resource "kubernetes_labels" "cosmotech_tiers" {
  for_each = {
    for key, value in var.hosts : key => value
    if value.type != "controlplane" && contains(keys(local.node_ip_to_name), value.ip)
  }

  api_version = "v1"
  kind        = "Node"

  metadata {
    name = local.node_ip_to_name[each.value.ip]
  }

  labels = {
    "cosmotech.com/tier" = each.value.type
    "vendor"             = "cosmotech"
  }
}


resource "kubernetes_node_taint" "cosmotech_taints" {
  for_each = {
    for key, value in var.hosts : key => value
    if value.type != "controlplane" && contains(keys(local.node_ip_to_name), value.ip)
  }

  metadata {
    name = local.node_ip_to_name[each.value.ip]
  }

  taint {
    key    = "vendor"
    value  = "cosmotech"
    effect = "NoSchedule"
  }
}


# The taints & labels can take time to be applied. Just a timer to be sure the nexts Terraform resources will works as expected
resource "time_sleep" "wait_for_kubernetes_propagation" {
  create_duration = "30s"
  depends_on = [
    kubernetes_labels.cosmotech_tiers,
    kubernetes_node_taint.cosmotech_taints
  ]
}