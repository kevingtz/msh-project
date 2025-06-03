terraform {
  backend "gcs" {
    bucket = "smt-the-prd-kevinloygtz-r4ch-terraform-state-prd"
    prefix = "prd/terraform/state"
  }
}
