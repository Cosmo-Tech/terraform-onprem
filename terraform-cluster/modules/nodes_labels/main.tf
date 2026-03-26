locals {
  node_ip_to_name = {
    for node in data.kubernetes_nodes.all_nodes.nodes : flatten([for addr in node.status[0].addresses : addr.address if addr.type == "InternalIP"])[0] => node.metadata[0].name
  }
}


data "kubernetes_nodes" "all_nodes" {}


# Simple trigger to ensure applying the resources
resource "terraform_data" "trigger_refresh" {
  input = timestamp()
}


# Set cosmotech labels
# The labels are automatically applied on nodes based on their real IP address vs the IP address you setted in terraform.tfvars
resource "kubernetes_labels" "cosmotech_labels" {
  for_each = {
    for key, value in var.hosts : key => value
    if value.type != "controlplane" && contains(keys(local.node_ip_to_name), value.ip)
  }

  api_version   = "v1"
  kind          = "Node"
  force         = true
  field_manager = "terraform-cosmotech"

  metadata {
    name = local.node_ip_to_name[each.value.ip]
  }

  labels = {
    "cosmotech.com/tier" = each.value.type
    "cosmotech.com/size" = each.value.type == "compute" ? each.value.size : null
    "vendor" = "cosmotech"
  }

  lifecycle {
    replace_triggered_by = [terraform_data.trigger_refresh]
  }
}


# Set vendor=cosmotech:NoSchedule taint
# The labels are automatically applied on nodes based on their real IP address vs the IP address you setted in terraform.tfvars
resource "kubernetes_node_taint" "cosmotech_taints" {
  for_each = {
    for key, value in var.hosts : key => value
    if value.type != "controlplane" && contains(keys(local.node_ip_to_name), value.ip)
  }

  force         = true
  field_manager = "terraform-cosmotech"

  metadata {
    name = local.node_ip_to_name[each.value.ip]
  }

  taint {
    key    = "vendor"
    value  = "cosmotech"
    effect = "NoSchedule"
  }

  lifecycle {
    replace_triggered_by = [terraform_data.trigger_refresh]
  }
}
