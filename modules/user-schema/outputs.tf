# ========================================
# Module Outputs
# ========================================

output "custom_attributes" {
  description = "Map of all custom user schema attributes"
  value = {
    for name, attr in okta_user_schema_property.custom_attributes : name => {
      id          = attr.id
      index       = attr.index
      title       = attr.title
      type        = attr.type
      description = attr.description
      master      = attr.master
      permissions = attr.permissions
      required    = attr.required
      scope       = attr.scope
      unique      = attr.unique
    }
  }
}

output "attribute_names" {
  description = "List of all managed attribute names"
  value       = keys(local.attribute_map)
}

output "attribute_count" {
  description = "Count of managed attributes"
  value       = length(local.attribute_map)
}

output "metadata" {
  description = "Metadata about the attribute configuration"
  value       = local.metadata
}

output "validation_status" {
  description = "Validation status of attributes"
  value = {
    has_errors    = length(local.actual_validation_errors) > 0
    errors        = local.actual_validation_errors
    has_warnings  = length(local.reserved_conflicts) > 0
    warnings      = local.reserved_conflicts
  }
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "region" {
  description = "Region identifier"
  value       = var.region
}

output "okta_org_name" {
  description = "Okta organization name"
  value       = var.okta_org_name
  sensitive   = true
}

output "user_type_id" {
  description = "User type ID attributes are attached to"
  value       = data.okta_user_type.default.id
}

# Summary output for quick overview
output "summary" {
  description = "Summary of schema management"
  value = {
    environment      = var.environment
    region          = var.region
    total_attributes = length(local.attribute_map)
    base_attributes = local.metadata.base_attributes
    overrides      = local.metadata.overrides
    additions      = local.metadata.additions
    status         = length(local.actual_validation_errors) > 0 ? "ERROR" : "OK"
  }
}