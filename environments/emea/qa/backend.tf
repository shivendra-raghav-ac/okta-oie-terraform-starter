# ========================================
# Terraform Backend Configuration (QA)
# ========================================

terraform {
  backend "s3" {
    bucket       = "okta-terraform-state-qa"
    key          = "emea/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
