# ========================================
# Local Values and Attribute Processing
# ========================================

locals {
  # Construct override path if not provided
  override_path = var.override_attributes_path != null ? var.override_attributes_path : "${path.module}/../../attributes/overrides/${var.environment}.yaml"
  
  # Read and decode YAML files
  base_attributes_raw = fileexists(var.base_attributes_path) ? file(var.base_attributes_path) : "{}"
  override_attributes_raw = fileexists(local.override_path) ? file(local.override_path) : "{}"
  
  base_attributes_data = yamldecode(local.base_attributes_raw)
  override_attributes_data = yamldecode(local.override_attributes_raw)
  
  # Extract base attributes
  base_attributes = try(local.base_attributes_data.attributes, [])
  
  # Extract overrides and additions
  attribute_overrides = try(local.override_attributes_data.overrides, [])
  attribute_additions = try(local.override_attributes_data.additions, [])
  
  # Create override map for easier lookup
  override_map = {
    for override in local.attribute_overrides : override.name => override
  }
  
  # Merge base attributes with overrides
  merged_base_attributes = [
    for attr in local.base_attributes : merge(
      attr,
      try(local.override_map[attr.name], {})
    )
  ]
  
  # Combine merged base attributes with additions
  all_attributes = concat(local.merged_base_attributes, local.attribute_additions)
  
  # Create final attribute map with computed properties
  attribute_map = {
    for attr in local.all_attributes : attr.name => merge(
      {
        # Defaults
        index                    = attr.name
        title                   = try(attr.display_name, attr.name)
        type                    = attr.type
        description             = try(attr.description, "Custom attribute: ${attr.name}")
        master                  = try(attr.master, "PROFILE_MASTER")
        permissions             = try(attr.permissions, "READ_WRITE")
        required                = try(attr.required, false)
        scope                   = try(attr.scope, "NONE")
        unique                  = try(attr.unique, null)
        pattern                 = try(attr.pattern, null)
        min_length              = try(attr.min_length, null)
        max_length              = try(attr.max_length, null)
        enum                    = try(attr.enum, null)
        one_of                  = try(attr.one_of, null)
        array_type              = try(attr.array_type, null)
        array_enum              = try(attr.array_enum, null)
        array_one_of            = try(attr.array_one_of, null)
        external_name           = try(attr.external_name, null)
        external_namespace      = try(attr.external_namespace, null)
        master_override_priority = try(attr.master_override_priority, null)
      },
      attr
    )
  }
  
  # Metadata for tracking
  metadata = {
    environment         = var.environment
    region             = var.region
    managed_by         = var.managed_by
    last_modified      = timestamp()
    base_attributes    = length(local.base_attributes)
    overrides         = length(local.attribute_overrides)
    additions         = length(local.attribute_additions)
    total_attributes  = length(local.attribute_map)
  }
  
  # Validation rules
  validation_errors = flatten([
    for name, attr in local.attribute_map : [
      # Check for invalid type combinations
      attr.type == "array" && attr.array_type == null ? 
        "Attribute '${name}' has type 'array' but missing 'array_type'" : null,
      
      # Check for invalid enum configurations
      attr.type != "string" && attr.enum != null ? 
        "Attribute '${name}' has enum but type is not string" : null,
      
      # Check for pattern on non-string types
      attr.type != "string" && attr.pattern != null ? 
        "Attribute '${name}' has pattern but type is not string" : null,
      
      # Check for length constraints on non-string types
      attr.type != "string" && (attr.min_length != null || attr.max_length != null) ? 
        "Attribute '${name}' has length constraints but type is not string" : null,
      
      # Check min/max length logic
      attr.min_length != null && attr.max_length != null && attr.min_length > attr.max_length ?
        "Attribute '${name}' has min_length > max_length" : null,
    ]
  ])
  
  # Filter out null validation errors
  actual_validation_errors = [for err in local.validation_errors : err if err != null]
  
  # Reserved attribute names that shouldn't be used
  reserved_names = [
    "login", "email", "secondEmail", "firstName", "lastName", 
    "middleName", "honorificPrefix", "honorificSuffix", "title",
    "displayName", "nickName", "profileUrl", "primaryPhone",
    "mobilePhone", "streetAddress", "city", "state", "zipCode",
    "countryCode", "postalAddress", "preferredLanguage", "locale",
    "timezone", "userType", "employeeNumber", "costCenter", 
    "organization", "division", "department", "managerId", 
    "manager"
  ]
  
  # Check for reserved names
  reserved_conflicts = [
    for name, _ in local.attribute_map : name 
    if contains(local.reserved_names, name)
  ]
}