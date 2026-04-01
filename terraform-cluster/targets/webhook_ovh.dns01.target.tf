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
