# ========================================
# Terraform & Provider Version Constraints
# ========================================

terraform {
  required_version = ">= 1.13.3"

  required_providers {
    okta = {
      source  = "okta/okta"
      version = "~> 6.5.0"
    }
  }
}

# ========================================
# Okta Provider Configuration
# ========================================
# Credentials via environment variables:
#   - OKTA_ORG_NAME
#   - OKTA_BASE_URL
#   - OKTA_CLIENT_ID
#   - OKTA_PRIVATE_KEY_ID
#   - OKTA_PRIVATE_KEY
#   - OKTA_SCOPES
#
# NOTE:
#   The provider automatically reads these values. 
#   No inline secrets in Terraform code.

provider "okta" {
  # Empty — configuration comes from environment variables
}
