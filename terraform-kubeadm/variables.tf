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

variable "override_naming_convention" {
  description = "Override the default naming convention (false => 'kob-<cluster_stage>-<cluster_name>'; true => cluster_name = the exact name that will be used)"
  type        = bool
}

variable "state_host" {
  description = "DNS record or IP of the server hosting the Terraform state"
  type        = string
}

variable "hosts" {
  description = "List of host where to perform the installation"
  type        = map(any)
}

variable "host_sudo_password" {
  description = "Enter sudo password to execute scripts on hosts. All hosts must have the same password"
  type        = string
  # sensitive = true
}