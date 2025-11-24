# ========================================
# Terraform Backend Configuration (QA)
# ========================================

terraform {
  backend "s3" {
    bucket       = "okta-terraform-state-qa"
    key          = "apac/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
