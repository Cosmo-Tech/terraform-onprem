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
    name      = "dns-challenge"
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