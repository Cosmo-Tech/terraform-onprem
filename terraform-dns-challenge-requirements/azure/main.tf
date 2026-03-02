# Create requirements on Azure to run a DNS challenge
# -> app registration with a secret
# -> store the secret in Kubernetes

terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.8.0"
    }
  }
}

provider "azuread" {
  # Configuration options
}

locals {
  main_name = "${var.main_name}-dns-challenge"
}

resource "azuread_application_registration" "cluster_dns_challenge" {
  display_name     = local.main_name
  sign_in_audience = "AzureADMyOrg"
}

resource "azuread_application_password" "cluster_dns_challenge" {
  application_id = azuread_application_registration.azure_client_app_registration.id
  display_name   = local.main_name
}


