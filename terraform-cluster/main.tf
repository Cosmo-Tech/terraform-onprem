locals {
  main_name      = var.override_naming_convention == true ? var.cluster_name : "kob-${var.cluster_stage}-${var.cluster_name}"
  cluster_domain = "${var.cluster_name}.${var.domain_zone}"

  # # Get the IP from the existing nodes
  # cluster_ip = flatten([
  #   for node in data.kubernetes_nodes.all_nodes.nodes : [
  #     for addr in node.status[0].addresses : addr.address if addr.type == "InternalIP"
  #   ]
  # ])[0]


  # Get the IP from the controlplane
  cluster_ip = flatten([
    for node in data.kubernetes_nodes.all_nodes.nodes : [
      for addr in node.status[0].addresses : addr.address
      if addr.type == "InternalIP" && lookup(node.metadata[0].labels, "node-role.kubernetes.io/control-plane", null) != null
    ]
  ])[0]
}


data "kubernetes_nodes" "all_nodes" {}


module "nodes_labels" {
  source = "./modules/nodes_labels"

  hosts        = var.hosts
  cluster_name = local.main_name
}


module "longhorn" {
  source = "./modules/longhorn"

  depends_on = [module.nodes_labels]
}


module "metallb" {
  source = "./modules/metallb"

  ip_address_for_web_services = var.ip_address_for_web_services
  ip_address_for_superset     = var.ip_address_for_superset

  depends_on = [module.nodes_labels]
}
