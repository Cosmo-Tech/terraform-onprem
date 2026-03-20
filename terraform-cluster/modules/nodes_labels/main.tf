locals {
  node_name = "${var.cluster_name}-${each.value.type}"
}


resource "kubernetes_labels" "cosmotech_tiers" {
  for_each = { for key, value in var.hosts : key => value if value.type != "controlplane" }

  api_version = "v1"
  kind        = "Node"

  metadata {
    name = local.node_name
  }

  labels = {
    "cosmotech.com/tier" = each.value.type
  }
}


resource "kubernetes_node_taint" "cosmotech_taints" {
  for_each = { for key, value in var.hosts : key => value if value.type != "controlplane" }

  metadata {
    name = local.node_name
  }

  taint {
    key    = "vendor"
    value  = "cosmotech"
    effect = "NoSchedule"
  }
}
