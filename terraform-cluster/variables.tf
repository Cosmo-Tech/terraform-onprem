
locals {
  main_name = var.override_naming_convention == true ? var.cluster_name : "kob-${var.cluster_stage}-${var.cluster_name}"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
}

variable "cluster_stage" {
  description = "Kubernetes cluster stage"
  type        = string

  validation {
    condition     = contains(["test", "dev", "qa", "demo", "ppd", "prod"], var.cluster_stage)
    error_message = "Valid values for 'cluster_stage' are: \n- test\n- dev\n- qa\n- demo\n- ppd\n- prod"
  }
}

variable "domain_zone" {
  description = "Domain zone containing the cluster domain"
  type        = string
}

variable "override_naming_convention" {
  description = "Override the default naming convention (false => 'kob-<cluster_stage>-<cluster_name>'; true => cluster_name = the exact name that will be used)"
  type        = bool
}

variable "install_kubeadm" {
  description = "Is kubeadm already installed ?"
  type        = bool
}

variable "dns_challenge_provider" {
  description = "Name of the provider where the DNS challenge needs to be setuped. This must match with the module name in 'terraform-dns-challenge-requirements'"
  type        = string
}

variable "state_host" {
  description = "DNS record or IP of the server hosting the Terraform state"
  type        = string
}
