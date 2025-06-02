# Create a storage bucket for the Cloud Function source code
resource "google_storage_bucket" "function_source" {
  name                        = "${var.project_id}-function-source-${var.environment}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy              = true

  versioning {
    enabled = true
  }
}

# Create source code archive
data "archive_file" "function_source" {
  type        = "zip"
  output_path = "function-source.zip"
  source {
    content  = file("${path.module}/main.py")
    filename = "main.py"
  }
  source {
    content  = file("${path.module}/requirements.txt")
    filename = "requirements.txt"
  }
}

# Upload source code to storage bucket
resource "google_storage_bucket_object" "function_source" {
  name   = "function-source-${data.archive_file.function_source.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.function_source.output_path
}

# Cloud Function
resource "google_cloudfunctions_function" "hello_world" {
  name                  = "hello-world-${var.environment}"
  runtime              = "python310"
  entry_point          = "hello_world"
  source_archive_bucket = google_storage_bucket.function_source.name
  source_archive_object = google_storage_bucket_object.function_source.name
  trigger_http         = true
  available_memory_mb  = 128
  timeout             = 60
  
  environment_variables = {
    ENV = var.environment
  }

  depends_on = [
    google_storage_bucket_object.function_source
  ]
}

# IAM policy to allow public access (will be restricted by Cloud Armor)
resource "google_cloudfunctions_function_iam_binding" "invoker" {
  project        = google_cloudfunctions_function.hello_world.project
  region         = google_cloudfunctions_function.hello_world.region
  cloud_function = google_cloudfunctions_function.hello_world.name

  role = "roles/cloudfunctions.invoker"

  members = [
    "allUsers",
  ]
}

# Enable Cloud Logging
resource "google_logging_project_sink" "function_logs" {
  name        = "function-logs-${var.environment}"
  destination = "storage.googleapis.com/${google_storage_bucket.function_source.name}"
  filter      = "resource.type=cloud_function AND resource.labels.function_name=${google_cloudfunctions_function.hello_world.name}"

  unique_writer_identity = true
} 