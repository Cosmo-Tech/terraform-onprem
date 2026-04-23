module "dns_challenges_requirements_azuredns" {
  source = "./modules/dns_challenges_requirements/azuredns"

  dns_challenge_provider = var.dns_challenge_provider
  main_name              = local.main_name
  domain_zone            = var.domain_zone
  cluster_ip             = local.cluster_ip
  cluster_domain         = local.cluster_domain
}
