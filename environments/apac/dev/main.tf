# ========================================
# Okta User Schema Management
# ========================================
# Environment: Will be set via variables
# Region: Will be set via variables

terraform {
  required_version = ">= 1.13.3"
}

# ========================================
# Local Values
# ========================================

locals {
  # Construct paths to attribute files
  base_attributes_path     = "${path.module}/../../../attributes/definitions/custom_attributes.yaml"
  override_attributes_path = "${path.module}/../../../attributes/overrides/${var.environment}.yaml"
  
  # Common tags/labels (for future use)
  common_tags = {
    Environment  = var.environment
    Region       = var.region
    ManagedBy    = "Terraform"
    Repository   = "okta-terraform"
    Owner        = var.owner
    CostCenter   = var.cost_center
    LastModified = timestamp()
  }
}

# ========================================
# User Schema Module
# ========================================

module "user_schema" {
  source = "../../../modules/user-schema"
  
  # Environment configuration
  environment = var.environment
  region      = var.region
  
  # Okta configuration
  okta_org_name       = var.okta_org_name
  okta_base_url       = var.okta_base_url
  okta_client_id      = var.okta_client_id
  okta_private_key    = var.okta_private_key
  okta_private_key_id = var.okta_private_key_id
  okta_scopes         = var.okta_scopes
  
  # User type configuration
  user_type_id = var.user_type_id
  
  # Attribute file paths
  base_attributes_path     = local.base_attributes_path
  override_attributes_path = local.override_attributes_path
  
  # Feature flags
  enable_drift_detection = var.enable_drift_detection
  
  # Metadata
  managed_by = var.managed_by
  tags       = local.common_tags
}