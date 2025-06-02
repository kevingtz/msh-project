output "function" {
  description = "The Cloud Function resource"
  value       = google_cloudfunctions_function.hello_world
}

output "function_url" {
  description = "The URL of the Cloud Function"
  value       = google_cloudfunctions_function.hello_world.https_trigger_url
}

output "function_name" {
  description = "The name of the Cloud Function"
  value       = google_cloudfunctions_function.hello_world.name
} 