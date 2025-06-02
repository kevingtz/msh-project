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

# Variables
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
  description = "Environment name (dev, test, prd)"
  type        = string
  default     = "dev"
}

variable "domains" {
  description = "List of domains for SSL certificate"
  type        = list(string)
  default     = ["example.com"]
}

# Enable required APIs first
module "apis" {
  source = "./modules/apis"
  
  project_id = var.project_id
}

# Cloud Function Module
module "cloud_function" {
  source = "./modules/cloud_function"
  
  project_id   = var.project_id
  region       = var.region
  environment  = var.environment
  
  # Wait for APIs to be enabled
  depends_on = [module.apis]
}

# Cloud Armor Module (creates backend service)
module "cloud_armor" {
  source = "./modules/cloud_armor"
  
  project_id = var.project_id
  
  # Wait for APIs to be enabled
  depends_on = [module.apis]
}

# Load Balancer Module (creates NEG and uses backend service)
module "load_balancer" {
  source = "./modules/load_balancer"
  
  project_id                = var.project_id
  region                    = var.region
  cloud_function            = module.cloud_function.function
  security_policy_self_link = module.cloud_armor.security_policy_self_link
  domain_name               = length(var.domains) > 0 ? var.domains[0] : "example.com"
  
  # Wait for APIs and Cloud Armor
  depends_on = [module.apis, module.cloud_armor]
}

# Outputs
output "load_balancer_url" {
  description = "The URL of the load balancer"
  value       = module.load_balancer.load_balancer_url
}

output "function_url" {
  description = "The URL of the Cloud Function"
  value       = module.cloud_function.function_url
} 