terraform {
  backend "gcs" {
    bucket = "smt-the-test-kevinloygtz-r4ch-terraform-state-test"
    prefix = "test/terraform/state"
  }
}
