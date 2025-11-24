# ========================================
# Module Variables
# ========================================

variable "environment" {
  description = "Environment name (dev, qa, val, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "qa", "val", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, val, prod"
  }
}

variable "region" {
  description = "Region identifier (apac, emea)"
  type        = string
  
  validation {
    condition     = contains(["apac", "emea"], var.region)
    error_message = "Region must be one of: apac, emea"
  }
}

variable "okta_org_name" {
  description = "Okta organization name"
  type        = string
  sensitive   = true
}

variable "okta_base_url" {
  description = "Okta base URL (okta.com or oktapreview.com)"
  type        = string
  default     = "okta.com"
  
  validation {
    condition     = contains(["okta.com", "oktapreview.com"], var.okta_base_url)
    error_message = "Base URL must be either okta.com or oktapreview.com"
  }
}

variable "okta_client_id" {
  description = "Okta OAuth application client ID"
  type        = string
  sensitive   = true
}

variable "okta_private_key" {
  description = "Okta OAuth application private key"
  type        = string
  sensitive   = true
}

variable "okta_private_key_id" {
  description = "Okta OAuth application private key ID (kid)"
  type        = string
  sensitive   = true
}

variable "okta_scopes" {
  description = "Okta OAuth scopes"
  type        = list(string)
  default     = ["okta.users.manage", "okta.schemas.manage"]
}

variable "user_type_id" {
  description = "Okta user type ID to attach schema properties to"
  type        = string
  default     = "default"
}

variable "base_attributes_path" {
  description = "Path to base custom attributes YAML file"
  type        = string
  default     = "../../../attributes/definitions/custom_attributes.yaml"
}

variable "override_attributes_path" {
  description = "Path to environment-specific override attributes YAML file"
  type        = string
  default     = null
}

variable "enable_drift_detection" {
  description = "Enable drift detection for attributes not managed by Terraform"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources (if supported in future)"
  type        = map(string)
  default     = {}
}

variable "managed_by" {
  description = "Team or system managing these attributes"
  type        = string
  default     = "terraform"
}