resource "kubernetes_secret" "dns_challenge" {
  count = var.dns_challenge_provider == "ovh" ? 1 : 0

  metadata {
    name      = "dns-challenge-terraform-onprem"
    namespace = "default"
  }

  data = {
    groupName         = var.ovh_group_name
    applicationKey    = var.ovh_application_key
    applicationSecret = var.ovh_application_secret
    consumerKey       = var.ovh_consumer_key
  }

  type = "Opaque"
}
