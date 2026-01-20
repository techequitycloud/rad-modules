locals {
  # Service account impersonation configuration
  impersonation_service_account = local.agent_service_account != null ? local.agent_service_account : local.resource_creator_identity
  impersonation_enabled         = local.impersonation_service_account != null && local.impersonation_service_account != ""
}

# Google Provider with optional service account impersonation
provider "google" {
  project = local.existing_project_id
  
  # ✅ FIXED: default_labels is an argument, not a block
  default_labels = local.resource_labels != null ? local.resource_labels : {}

  # Service account impersonation configuration
  access_token = local.impersonation_enabled ? data.external.impersonation_token[0].result.access_token : null
}

provider "google-beta" {
  project = local.existing_project_id
  
  default_labels = local.resource_labels != null ? local.resource_labels : {}

  # Service account impersonation configuration
  access_token = local.impersonation_enabled ? data.external.impersonation_token[0].result.access_token : null
}

# Get impersonation token if service account is specified
data "external" "impersonation_token" {
  count   = local.impersonation_enabled ? 1 : 0
  program = ["bash", "${path.module}/scripts/get-impersonation-token.sh", local.impersonation_service_account]
}
