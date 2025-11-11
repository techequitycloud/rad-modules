/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# Provider configuration for Google Cloud with impersonation capabilities.
provider "google" {
  alias = "impersonated"  # Alias used to reference this specific provider configuration

  # Scopes define the level of access the provider will have. In this case, full access to cloud platform resources and user email.
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email"
  ]
}

# Data source to obtain an access token for a service account with impersonation.
data "google_service_account_access_token" "default" {
  count                  = length(var.resource_creator_identity) != 0 ? 1 : 0  # Create this data source only if the resource creator identity is provided
  provider               = google.impersonated  # Use the impersonated provider instance
  scopes                 = ["userinfo-email", "cloud-platform"]  # Scopes for the access token, shorter form without full URL
  target_service_account = var.resource_creator_identity  # The service account to impersonate
  lifetime               = "1800s"  # The lifetime of the generated access token
}

# Default provider configuration for Google Cloud using the generated access token if available.
provider "google" {
  access_token = length(var.resource_creator_identity) != 0 ? data.google_service_account_access_token.default[0].access_token : null  # Use the access token from the data source if a resource creator identity is specified
}

# Beta provider configuration for Google Cloud using the generated access token if available.
provider "google-beta" {
  access_token = length(var.resource_creator_identity) != 0 ? data.google_service_account_access_token.default[0].access_token : null  # Use the access token from the data source if a resource creator identity is specified
}
