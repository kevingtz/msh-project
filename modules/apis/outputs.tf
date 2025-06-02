output "apis_ready" {
  description = "Indicates when all APIs are enabled and ready"
  value       = time_sleep.wait_for_apis.id
}

output "enabled_apis" {
  description = "List of enabled APIs"
  value = [
    google_project_service.compute_engine.service,
    google_project_service.cloud_functions.service,
    google_project_service.cloud_storage.service,
    google_project_service.cloud_logging.service,
    google_project_service.cloud_build.service,
    google_project_service.iam.service
  ]
} 