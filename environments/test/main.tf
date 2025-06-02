terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Variables specific to test environment
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

# Use the main module
module "hello_world_infrastructure" {
  source = "../../"
  
  project_id  = var.project_id
  region      = var.region
  environment = "test"
}

# Outputs
output "load_balancer_url" {
  description = "The URL of the load balancer"
  value       = module.hello_world_infrastructure.load_balancer_url
}

output "function_url" {
  description = "The URL of the Cloud Function"
  value       = module.hello_world_infrastructure.function_url
} 