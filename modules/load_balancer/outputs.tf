output "load_balancer_url" {
  description = "The URL of the load balancer"
  value       = "http://${google_compute_global_forwarding_rule.http_forwarding_rule.ip_address}"
}

output "load_balancer_https_url" {
  description = "The HTTPS URL of the load balancer"
  value       = "https://${google_compute_global_forwarding_rule.https_forwarding_rule.ip_address}"
}

output "load_balancer_ip" {
  description = "The IP address of the load balancer"
  value       = google_compute_global_forwarding_rule.http_forwarding_rule.ip_address
}

output "neg_id" {
  description = "The ID of the Network Endpoint Group"
  value       = google_compute_region_network_endpoint_group.neg.id
}

output "backend_service" {
  description = "The backend service resource"
  value       = google_compute_backend_service.backend_service
}

output "backend_service_id" {
  description = "The ID of the backend service"
  value       = google_compute_backend_service.backend_service.id
} 