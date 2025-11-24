# ========================================
# Terraform Backend Configuration (VAL)
# ========================================

terraform {
  backend "s3" {
    bucket       = "okta-terraform-state-val"
    key          = "emea/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
