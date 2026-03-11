# Create requirements on Azure to run a DNS challenge
# -> app registration with a secret
# -> store the secret in Kubernetes

terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.8.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.62.0"
    }
  }
}

provider "azurerm" {
  features {}
}


locals {
  main_name = "${var.main_name}-dns-challenge"
}

# Create app registration
resource "azuread_application_registration" "dns_challenge" {
  count = var.dns_challenge_provider == "azure" ? 1 : 0

  display_name     = local.main_name
  sign_in_audience = "AzureADMyOrg"
}

# Create a secret on the app registration
resource "azuread_application_password" "dns_challenge" {
  count = var.dns_challenge_provider == "azure" ? 1 : 0

  application_id = azuread_application_registration.dns_challenge[0].id
  display_name   = local.main_name
}

# Create service principal of the app registration
resource "azuread_service_principal" "dns_challenge" {
  count      = var.dns_challenge_provider == "azure" ? 1 : 0
  client_id  = azuread_application_registration.dns_challenge[0].client_id
}

# Add permission to the service principal
resource "azurerm_role_assignment" "dns_contributor" {
  count                = var.dns_challenge_provider == "azure" ? 1 : 0
  scope                = data.azurerm_dns_zone.zone.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azuread_service_principal.dns_challenge[0].object_id
}

# Gather needed informations to store in Kubernetes secret
data "azuread_client_config" "current" {}
data "azurerm_subscription" "current" {}
data "azurerm_dns_zone" "zone" {
  name = var.domain_zone
}

# Create a Kubernetes secret to store the app registration informations
resource "kubernetes_secret" "dns_challenge" {
  count = var.dns_challenge_provider == "azure" ? 1 : 0

  metadata {
    name      = "dns-challenge-terraform-onprem"
    namespace = "default"
  }

  data = {
    client-id       = azuread_application_registration.dns_challenge[0].client_id
    client-secret   = azuread_application_password.dns_challenge[0].value
    domain-zone     = var.domain_zone
    domain-zone-rg  = data.azurerm_dns_zone.zone.resource_group_name
    subscription-id = data.azurerm_subscription.current.subscription_id
    tenant-id       = data.azuread_client_config.current.tenant_id
  }

  type = "Opaque"
}


# # Create DNS records cluster & Superset
# resource "azurerm_dns_a_record" "record_cluster" {
#   name                = var.cluster_domain
#   zone_name           = var.domain_zone
#   resource_group_name = data.azurerm_dns_zone.zone.resource_group_name
#   ttl                 = 300
#   records             = ["${var.cluster_ip}"]
# }

# resource "azurerm_dns_a_record" "record_superset" {
#   name                = "superset-${var.cluster_domain}"
#   zone_name           = var.domain_zone
#   resource_group_name = data.azurerm_dns_zone.zone.resource_group_name
#   ttl                 = 300
#   records             = ["${var.cluster_ip}"]
# }
