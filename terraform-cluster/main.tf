module "longhorn" {
  source = "./modules/longhorn"
}


module "metallb" {
  source = "./modules/metallb"
}


module "dns_challenges_requirements_azure" {
  source = "./modules/dns_challenges_requirements/azure"

  main_name              = local.main_name
  dns_challenge_provider = var.dns_challenge_provider
  domain_zone            = var.domain_zone
}
