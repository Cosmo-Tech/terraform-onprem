variable "cluster_ip" {
  type = string
}

variable "ip_range_size" {
  description = "Number of IPs to allocate in the MetalLB pool (starting from cluster_ip)"
  type        = number
  default     = 6

  validation {
    condition     = var.ip_range_size >= 1 && floor(var.ip_range_size) == var.ip_range_size
    error_message = "ip_range_size must be an integer greater than or equal to 1."
  }
}
