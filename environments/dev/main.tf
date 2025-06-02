terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Input variables
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "domains" {
  description = "List of domains for SSL certificate"
  type        = list(string)
  default     = ["example.com"]
}

# Use the main infrastructure module
module "hello_world_infrastructure" {
  source = "../../"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  domains     = var.domains
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