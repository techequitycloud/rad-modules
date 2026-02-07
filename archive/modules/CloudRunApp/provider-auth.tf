locals {
  # Service account impersonation configuration
  impersonation_service_account = local.agent_service_account != null ? local.agent_service_account : (local.resource_creator_identity != null ? local.resource_creator_identity : "")
  impersonation_enabled         = local.impersonation_service_account != null && local.impersonation_service_account != ""
  
  # ✅ NEW: Validate that the token is not empty
  impersonation_token_raw = local.impersonation_enabled ? data.external.impersonation_token[0].result.access_token : ""
  impersonation_token_valid = local.impersonation_token_raw != null && local.impersonation_token_raw != ""
  
  # Only use token if it's valid, otherwise use null (default credentials)
  impersonation_token = local.impersonation_token_valid ? local.impersonation_token_raw : null
}

# Get impersonation token if service account is specified
data "external" "impersonation_token" {
  count   = local.impersonation_enabled ? 1 : 0
  program = ["bash", "${path.module}/scripts/core/get-impersonation-token.sh", local.impersonation_service_account]
}

# Google Provider with optional service account impersonation
provider "google" {
  project = local.existing_project_id
  
  default_labels = local.resource_labels != null ? local.resource_labels : {}

  # ✅ FIXED: Use validated token (null if empty, which uses default credentials)
  access_token = local.impersonation_token
}

provider "google-beta" {
  project = local.existing_project_id
  
  default_labels = local.resource_labels != null ? local.resource_labels : {}

  # ✅ FIXED: Use validated token
  access_token = local.impersonation_token
}
