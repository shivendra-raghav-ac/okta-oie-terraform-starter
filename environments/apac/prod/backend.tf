# ========================================
# Terraform Backend Configuration (PROD)
# ========================================

terraform {
  backend "s3" {
    bucket       = "okta-terraform-state-prod"
    key          = "apac/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
