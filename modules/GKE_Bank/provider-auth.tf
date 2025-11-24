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

# Default provider configuration for Google Cloud using the generated access token if available.
provider "google" {
}

# Beta provider configuration for Google Cloud using the generated access token if available.
provider "google-beta" {
}
