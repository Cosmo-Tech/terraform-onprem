terraform {
  required_version = ">= 1.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # Pour l'instant, ce Terraform "bootstrap" doit utiliser un backend local
  # car c'est lui qui crée le serveur HTTP pour les autres projets.
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "docker" {
  # Connexion au Docker local de ton Linux
  host = "unix:///var/run/docker.sock"
}