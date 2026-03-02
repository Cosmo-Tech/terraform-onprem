variable "state_path" {
  description = "Chemin local sur le Linux pour stocker les fichiers .tfstate"
  default     = "/opt/terraform/states"
}

variable "admin_password" {
  description = "Mot de passe pour le Basic Auth"
  sensitive   = true
}
