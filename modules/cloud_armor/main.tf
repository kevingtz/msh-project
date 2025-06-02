# Cloud Armor Security Policy - Direct implementation
resource "google_compute_security_policy" "policy" {
  name        = "hello-world-policy"
  description = "Hello World Security Policy"
  project     = var.project_id

  # Default rule to allow traffic
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule, higher priority overrides it"
  }

  # Block specific regions
  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "origin.region_code == 'CN' || origin.region_code == 'RU'"
      }
    }
    description = "Deny traffic from specific regions"
  }

  # Rate limiting rule
  rule {
    action   = "rate_based_ban"
    priority = "1001"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Rate limiting rule"
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      ban_duration_sec = 600
    }
  }
}

# Health check for the backend service
resource "google_compute_health_check" "health_check" {
  name                = "hello-world-health-check"
  description         = "Health check for hello world function"
  timeout_sec         = 5
  check_interval_sec  = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/"
  }
} 