# Copyright 2024 (c) Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Provider configuration for Google Cloud with impersonation capabilities.
provider "google" {
  alias = "impersonated"  # Alias used to reference this specific provider configuration

  # Scopes define the level of access the provider will have. In this case, full access to cloud platform resources and user email.
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email"
  ]
}

# Local variables to determine which service account to use for impersonation
locals {
  # Use agent_service_account if provided, otherwise fall back to resource_creator_identity
  # This supports the impersonation chain: rad-module-creator -> rad-agent -> target project
  target_service_account = coalesce(
    try(var.agent_service_account, null),
    var.resource_creator_identity
  )
  
  # Determine if we should use impersonation
  use_impersonation = local.target_service_account != null && length(local.target_service_account) > 0
}

# Data source to obtain an access token for a service account with impersonation.
# This enables the impersonation chain:
# 1. Cloud Build runs as rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com
# 2. rad-module-creator impersonates rad-agent@gcp-project-eb45.iam.gserviceaccount.com
# 3. rad-agent has Owner permissions on the target project
data "google_service_account_access_token" "default" {
  count                  = local.use_impersonation ? 1 : 0  # Create this data source only if impersonation is needed
  provider               = google.impersonated  # Use the impersonated provider instance
  scopes                 = ["userinfo-email", "cloud-platform"]  # Scopes for the access token, shorter form without full URL
  target_service_account = local.target_service_account  # The service account to impersonate (rad-agent)
  lifetime               = "3600s"  # The lifetime of the generated access token (1 hour)
}

# Default provider configuration for Google Cloud using the generated access token if available.
provider "google" {
  project      = var.existing_project_id  # Target project where resources will be created
  region       = local.region  # Primary region for resources
  access_token = local.use_impersonation ? data.google_service_account_access_token.default[0].access_token : null  # Use the access token from impersonation
}

# Beta provider configuration for Google Cloud using the generated access token if available.
# This is needed for beta/preview features
provider "google-beta" {
  project      = var.existing_project_id  # Target project where resources will be created
  region       = local.region  # Primary region for resources
  access_token = local.use_impersonation ? data.google_service_account_access_token.default[0].access_token : null  # Use the access token from impersonation
}
