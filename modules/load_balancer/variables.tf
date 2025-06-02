variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "cloud_function" {
  description = "The Cloud Function resource"
  type        = any
}

variable "security_policy_self_link" {
  description = "The self link of the Cloud Armor security policy"
  type        = string
}

variable "domain_name" {
  description = "Domain name for SSL certificate (optional)"
  type        = string
  default     = ""
} 