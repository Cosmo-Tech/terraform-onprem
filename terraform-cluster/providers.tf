terraform {
  required_version = ">= 1.13.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0.2"
    }
  }

  
  # backend "http" {
  #   address = "http://myrest.api.com/foo"
  #   lock_address = "http://myrest.api.com/foo"
  #   unlock_address = "http://myrest.api.com/foo"
  # }

  
  backend "http" {
    address = "http://10.2.0.108"
    lock_address = "http://10.2.0.108"
    unlock_address = "http://10.2.0.108"
  }
}


provider "kubernetes" {
  config_path            = "~/.kube/config"
  config_context_cluster = local.main_name
}

provider "helm" {
  kubernetes = {
    config_path            = "~/.kube/config"
    config_context_cluster = local.main_name
  }
}
