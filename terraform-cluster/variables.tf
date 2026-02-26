
locals {
  main_name = "kob-${var.cluster_stage}-${var.cluster_name}"
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

variable "install_kubeadm" {
  description = "Is kubeadm already installed ?"
  type        = bool
}

