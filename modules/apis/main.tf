# Enable required GCP APIs
resource "google_project_service" "compute_engine" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy = false
}

resource "google_project_service" "cloud_functions" {
  project = var.project_id
  service = "cloudfunctions.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy = false
}

resource "google_project_service" "cloud_storage" {
  project = var.project_id
  service = "storage.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy = false
}

resource "google_project_service" "cloud_logging" {
  project = var.project_id
  service = "logging.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy = false
}

resource "google_project_service" "cloud_build" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  project = var.project_id
  service = "iam.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy = false
}

# Wait for APIs to be fully enabled before proceeding
resource "time_sleep" "wait_for_apis" {
  depends_on = [
    google_project_service.compute_engine,
    google_project_service.cloud_functions,
    google_project_service.cloud_storage,
    google_project_service.cloud_logging,
    google_project_service.cloud_build,
    google_project_service.iam
  ]

  create_duration = "60s"
} 