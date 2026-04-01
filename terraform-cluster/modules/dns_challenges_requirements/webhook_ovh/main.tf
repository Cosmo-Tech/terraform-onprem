data "template_file" "chart_values_webhook_ovh" {
  count = var.dns_challenge_provider == "ovh" ? 1 : 0

  template = file("${path.module}/values.yaml")
  vars = {
    group_name = var.ovh_group_name
  }
}

resource "helm_release" "cert_manager_webhook_ovh" {
  count = var.dns_challenge_provider == "ovh" ? 1 : 0

  name             = "cert-manager-webhook-ovh"
  repository       = "https://aureq.github.io/cert-manager-webhook-ovh/"
  chart            = "cert-manager-webhook-ovh"
  version          = "0.9.5"
  namespace        = "cert-manager"
  create_namespace = true

  values = [
    data.template_file.chart_values_webhook_ovh[0].rendered
  ]
}

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
