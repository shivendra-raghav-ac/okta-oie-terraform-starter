# ========================================
# Okta Custom User Schema Properties
# ========================================

resource "okta_user_schema_property" "custom_attributes" {
  for_each = local.attribute_map
  
  index       = each.value.index
  title       = each.value.title
  type        = each.value.type
  description = each.value.description
  
  # Master and permissions
  master      = each.value.master
  permissions = each.value.permissions
  
  # Required and scope
  required = each.value.required
  scope    = each.value.scope
  
  # Unique constraint
  unique = each.value.unique
  
  # String validation
  pattern    = each.value.type == "string" ? each.value.pattern : null
  min_length = each.value.type == "string" ? each.value.min_length : null
  max_length = each.value.type == "string" ? each.value.max_length : null
  
  # Enum values (for string type)
  enum = each.value.type == "string" ? each.value.enum : null
  
  # One-of configuration
  dynamic "one_of" {
    for_each = each.value.one_of != null ? each.value.one_of : []
    content {
      const = one_of.value.const
      title = one_of.value.title
    }
  }
  
  # Array configuration
  array_type = each.value.type == "array" ? each.value.array_type : null
  array_enum = each.value.type == "array" ? each.value.array_enum : null
  
  # Array one-of configuration
  dynamic "array_one_of" {
    for_each = each.value.array_one_of != null ? each.value.array_one_of : []
    content {
      const = array_one_of.value.const
      title = array_one_of.value.title
    }
  }
  
  # External mapping
  external_name      = each.value.external_name
  external_namespace = each.value.external_namespace
  
  # Master override priority
  dynamic "master_override_priority" {
    for_each = each.value.master_override_priority != null ? each.value.master_override_priority : []
    content {
      type  = try(master_override_priority.value.type, null)
      value = master_override_priority.value.value
    }
  }
  
  # User type association
  user_type = data.okta_user_type.default.id
  
  lifecycle {
    # Prevent accidental deletion of critical attributes
    prevent_destroy = false  # Set to true for production
    
    # Ignore changes that might be made in Okta UI
    ignore_changes = [
      # Uncomment if you want to ignore UI changes
      # description,
    ]
  }
}

# ========================================
# Optional: Manage Base Schema Properties
# ========================================
# Only for updating permissions or required status

resource "okta_user_base_schema_property" "firstName" {
  count = var.environment == "prod" ? 1 : 0
  
  index    = "firstName"
  title    = "First name"
  type     = "string"
  required = true  # Make required in production
  master   = "OKTA"
  user_type = data.okta_user_type.default.id
}

resource "okta_user_base_schema_property" "lastName" {
  count = var.environment == "prod" ? 1 : 0
  
  index    = "lastName"
  title    = "Last name"
  type     = "string"
  required = true  # Make required in production
  master   = "OKTA"
  user_type = data.okta_user_type.default.id
}