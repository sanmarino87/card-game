# ============================================
# terraform/variables.tf
# ============================================

variable "cloud_name" {
  description = "Cloud name from clouds.yaml"
  type        = string
  default     = "cyso"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "card-game"
}

variable "environment" {
  description = "Environment (production/staging/dev)"
  type        = string
  default     = "production"
}

variable "image_name" {
  description = "OS Image name"
  type        = string
  default     = "Ubuntu 22.04"
}

variable "flavor_name" {
  description = "Instance flavor (size)"
  type        = string
  default     = "m1.medium"
}

variable "network_name" {
  description = "Network name to attach instance to"
  type        = string
}

variable "key_pair" {
  description = "SSH key pair name"
  type        = string
}

variable "security_groups" {
  description = "Additional security groups"
  type        = list(string)
  default     = ["default"]
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!@#"
}

variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
  default     = ""
}

variable "admin_email" {
  description = "Admin email for SSL certificate"
  type        = string
  default     = "admin@example.com"
}