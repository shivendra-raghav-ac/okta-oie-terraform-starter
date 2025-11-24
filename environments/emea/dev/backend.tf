# ========================================
# Terraform Backend Configuration (DEV)
# ========================================

terraform {
  backend "s3" {
    bucket       = "okta-terraform-state-dev"
    key          = "emea/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
