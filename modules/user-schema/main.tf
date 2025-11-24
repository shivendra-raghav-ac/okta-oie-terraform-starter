# ========================================
# Okta Provider Configuration
# ========================================

provider "okta" {
  org_name       = var.okta_org_name
  base_url       = var.okta_base_url
  client_id      = var.okta_client_id
  private_key    = var.okta_private_key
  private_key_id = var.okta_private_key_id
  scopes         = var.okta_scopes
}

# ========================================
# Data Sources
# ========================================

# Get the user type to attach schema properties to
data "okta_user_type" "default" {
  name = var.user_type_id
}

# ========================================
# Validation
# ========================================

# Fail if there are validation errors
resource "null_resource" "validate_attributes" {
  count = length(local.actual_validation_errors) > 0 ? 1 : 0
  
  provisioner "local-exec" {
    command = "echo 'Validation errors: ${join(", ", local.actual_validation_errors)}' && exit 1"
  }
}

# Warn about reserved names (but don't fail)
resource "null_resource" "warn_reserved_names" {
  count = length(local.reserved_conflicts) > 0 ? 1 : 0
  
  provisioner "local-exec" {
    command = "echo 'WARNING: Using reserved attribute names: ${join(", ", local.reserved_conflicts)}'"
  }
}