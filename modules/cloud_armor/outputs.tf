output "security_policy" {
  description = "The Cloud Armor security policy"
  value       = google_compute_security_policy.policy
}

output "security_policy_self_link" {
  description = "The self link of the Cloud Armor security policy"
  value       = google_compute_security_policy.policy.self_link
} 