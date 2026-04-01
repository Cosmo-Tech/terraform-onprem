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


module "dns_challenges_requirements_azure" {
  source = "./modules/dns_challenges_requirements/azuredns"

  dns_challenge_provider = var.dns_challenge_provider
  main_name              = local.main_name
  domain_zone            = var.domain_zone
  cluster_ip             = local.cluster_ip
  cluster_domain         = local.cluster_domain
}


module "dns_challenges_requirements_webhook_ovh" {
  source = "./modules/dns_challenges_requirements/webhook_ovh"

  dns_challenge_provider = var.dns_challenge_provider
  ovh_group_name         = var.ovh_group_name
  ovh_application_key    = var.ovh_application_key
  ovh_application_secret = var.ovh_application_secret
  ovh_consumer_key       = var.ovh_consumer_key
}

variable "ovh_group_name" { type = string }
variable "ovh_application_key" { type = string }
variable "ovh_application_secret" { type = string }
variable "ovh_consumer_key" { type = string }
