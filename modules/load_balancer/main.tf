# Serverless Network Endpoint Group for Cloud Function
resource "google_compute_region_network_endpoint_group" "neg" {
  name                  = "cloud-function-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_function {
    function = var.cloud_function.name
  }

  depends_on = [var.cloud_function]
}

# Backend service for the load balancer
resource "google_compute_backend_service" "backend_service" {
  name                            = "hello-world-backend"
  description                     = "Backend service for hello world function"
  protocol                        = "HTTP"
  port_name                       = "http"
  timeout_sec                     = 30
  enable_cdn                      = false
  connection_draining_timeout_sec = 60

  # Attach Cloud Armor security policy
  security_policy = var.security_policy_self_link

  # Add the NEG as backend
  backend {
    group           = google_compute_region_network_endpoint_group.neg.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  # Note: Health checks are not supported with serverless NEGs
  # GCP automatically handles health checking for Cloud Functions

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL Map
resource "google_compute_url_map" "url_map" {
  name            = "hello-world-url-map"
  description     = "URL map for hello world application"
  default_service = google_compute_backend_service.backend_service.id
}

# HTTP Target Proxy
resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "hello-world-http-proxy"
  url_map = google_compute_url_map.url_map.id
}

# Global Forwarding Rule (HTTP)
resource "google_compute_global_forwarding_rule" "http_forwarding_rule" {
  name       = "hello-world-http-forwarding-rule"
  target     = google_compute_target_http_proxy.http_proxy.id
  port_range = "80"
  ip_protocol = "TCP"
}

# Optional: SSL Certificate and HTTPS setup
resource "google_compute_managed_ssl_certificate" "ssl_cert" {
  name = "hello-world-ssl-cert"

  managed {
    domains = [var.domain_name != "" ? var.domain_name : "example.com"]
  }
}

# HTTPS Target Proxy
resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "hello-world-https-proxy"
  url_map          = google_compute_url_map.url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.ssl_cert.id]
}

# Global Forwarding Rule (HTTPS)
resource "google_compute_global_forwarding_rule" "https_forwarding_rule" {
  name       = "hello-world-https-forwarding-rule"
  target     = google_compute_target_https_proxy.https_proxy.id
  port_range = "443"
  ip_protocol = "TCP"
} 