terraform {
  backend "gcs" {
    bucket = "smt-the-dev-kevinloygtz-r4ch-terraform-state-dev"
    prefix = "dev/terraform/state"
  }
}
