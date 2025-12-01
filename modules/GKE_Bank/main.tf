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

# Define local values for use throughout the Terraform configuration
locals {
  # Choose a deployment ID based on whether the user provides one or generate a new random ID
  random_id = var.deployment_id != null ? var.deployment_id : random_id.default[0].hex

  # Select the project resource depending on whether a new project is created or an existing one is used
  project        = try(data.google_project.existing_project, null)
  project_number = try(local.project.number, null)

  # List of default APIs to enable on the Google Cloud project
  default_apis = [
    "iap.googleapis.com",
    "container.googleapis.com",
    "compute.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "servicenetworking.googleapis.com",
    "containersecurity.googleapis.com",
    "iamcredentials.googleapis.com",
    "iam.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "cloudtrace.googleapis.com",
    "anthos.googleapis.com",
    "mesh.googleapis.com",
    "gkeconnect.googleapis.com",
    "gkehub.googleapis.com",
    "anthospolicycontroller.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
    "websecurityscanner.googleapis.com",
    "billingbudgets.googleapis.com",
 ]

  # Determine the list of APIs to enable based on whether additional services are requested
  project_services = var.enable_services ? local.default_apis : []
}

# Data source to fetch the list of available compute zones in the region
data "google_compute_zones" "available_zones" {
  project = local.project.project_id
  region  = var.gcp_region
  status  = "UP" # Filter for zones that are up and running
}

# Generate a random ID if a deployment ID is not provided
resource "random_id" "default" {
  count       = var.deployment_id == null ? 1 : 0 # Only create if no deployment ID is given
  byte_length = 2 # The length of the random byte sequence to generate
}

# Data source to fetch information about an existing Google Cloud project, if not creating a new one
data "google_project" "existing_project" {
  project_id = trimspace(var.existing_project_id)
}

# Resource to enable APIs on the selected Google Cloud project
resource "google_project_service" "enabled_services" {
  for_each                   = toset(local.project_services) # Iterate over each service in the set
  project                    = local.project.project_id      # Apply to the selected project
  service                    = each.value                    # The API service to enable
  
  # ✅ CRITICAL: Prevent APIs from being disabled during terraform destroy
  disable_dependent_services = false  # Changed from true
  disable_on_destroy         = false  # Changed from true
}
