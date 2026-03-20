resource "kubernetes_labels" "cosmotech_tiers" {
  for_each = { for key, value in var.hosts : key => value if value.type != "controlplane" }

  api_version = "v1"
  kind        = "Node"

  metadata {
    name = "${var.cluster_name}-${each.value.type}"
  }

  labels = {
    "cosmotech.com/tier" = each.value.type
  }
}


resource "kubernetes_node_taint" "cosmotech_taints" {
  for_each = { for key, value in var.hosts : key => value if value.type != "controlplane" }

  metadata {
    name = "${var.cluster_name}-${each.value.type}"
  }

  taint {
    key    = "vendor"
    value  = "cosmotech"
    effect = "NoSchedule"
  }
}


# The taints & labels can take time to be applied. Just a timer to be sure the nexts Terraform resources will works as expected
resource "time_sleep" "wait_for_kubernetes_propagation" {
  depends_on = [
    kubernetes_labels.cosmotech_tiers,
    kubernetes_node_taint.cosmotech_taints
  ]

  create_duration = "30s"
}
