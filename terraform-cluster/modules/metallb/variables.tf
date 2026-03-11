variable "cluster_ip" {
  type = string
}

variable "ip_range_size" {
  description = "Number of IPs to allocate in the MetalLB pool (starting from cluster_ip)"
  type        = number
  default     = 6
}