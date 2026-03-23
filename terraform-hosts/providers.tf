terraform {
  required_version = ">= 1.13.0"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.5.0"
    }
  }

  backend "http" {
    update_method = "PUT"
    lock_method   = "POST"
    unlock_method = "DELETE"

    # 'skip_cert_verification' is setted to true in order to be able using the Caddy server (which is configured with default TLS certificates, as the state storage (=the Caddy server) must exists before launching Terraform... Chicken or the egg dilemma). But it can be manually configured later using the DNS challenge.
    skip_cert_verification = true
  }
}
