locals {
  main_name      = var.override_naming_convention == true ? var.cluster_name : "kob-${var.cluster_stage}-${var.cluster_name}"
  cluster_domain = "${var.cluster_name}.${var.domain_zone}"

  # Get the IP from the existing nodes
  cluster_ip = flatten([
    for node in data.kubernetes_nodes.all_nodes.nodes : [
      for addr in node.status[0].addresses : addr.address if addr.type == "InternalIP"
    ]
  ])[0]
}


data "kubernetes_nodes" "all_nodes" {}


module "nodes_labels" {
  source = "./modules/nodes_labels"

  hosts = var.hosts
  cluster_name = local.main_name
}


module "longhorn" {
  source = "./modules/longhorn"

  depends_on = [ module.nodes_labels ]
}


module "metallb" {
  source = "./modules/metallb"

  cluster_ip = local.cluster_ip

  depends_on = [ module.nodes_labels ]
}


module "dns_challenges_requirements_azure" {
  source = "./modules/dns_challenges_requirements/azure"

  main_name              = local.main_name
  dns_challenge_provider = var.dns_challenge_provider
  domain_zone            = var.domain_zone
  cluster_ip             = local.cluster_ip
  cluster_domain         = local.cluster_domain
}
