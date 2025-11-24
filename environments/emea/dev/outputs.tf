# ========================================
# Terraform Outputs
# ========================================

# ========================================
# Module Outputs (Pass-through)
# ========================================

output "custom_attributes" {
  description = "Map of all custom user schema attributes"
  value       = module.user_schema.custom_attributes
  sensitive   = false
}

output "attribute_names" {
  description = "List of all managed attribute names"
  value       = module.user_schema.attribute_names
}

output "attribute_count" {
  description = "Total count of managed attributes"
  value       = module.user_schema.attribute_count
}

# ========================================
# Environment Information
# ========================================

output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "region" {
  description = "Current region"
  value       = var.region
}

output "okta_org_name" {
  description = "Okta organization name"
  value       = var.okta_org_name
  sensitive   = true
}

# ========================================
# Metadata Outputs
# ========================================

output "metadata" {
  description = "Metadata about the deployment"
  value = {
    environment      = var.environment
    region          = var.region
    okta_org        = var.okta_org_name
    okta_base_url   = var.okta_base_url
    user_type_id    = var.user_type_id
    managed_by      = var.managed_by
    owner           = var.owner
    last_applied    = timestamp()
  }
  sensitive = false
}

output "validation_status" {
  description = "Attribute validation status"
  value       = module.user_schema.validation_status
}

# ========================================
# Summary Output
# ========================================

output "summary" {
  description = "Deployment summary"
  value       = module.user_schema.summary
}

# ========================================
# Quick Status Output
# ========================================

output "deployment_info" {
  description = "Quick deployment information"
  value = {
    deployment = "${var.environment}-${var.region}"
    attributes = {
      total    = module.user_schema.attribute_count
      names    = module.user_schema.attribute_names
    }
    status = try(
      module.user_schema.validation_status.has_errors ? "ERROR" : "OK",
      "UNKNOWN"
    )
  }
}