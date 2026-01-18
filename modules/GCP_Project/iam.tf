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

locals {
  devops_roles = [
    # Core AI/ML Roles
    "roles/aiplatform.user",
    "roles/aiplatform.admin",
    "roles/ml.developer",
    "roles/cloudvision.user",
    "roles/language.user",

    # Development & Deployment Roles
    "roles/run.admin",
    "roles/run.developer",
    "roles/cloudfunctions.admin",
    "roles/cloudfunctions.developer",
    "roles/cloudbuild.builds.editor",
    "roles/artifactregistry.admin",
    "roles/secretmanager.admin",
    "roles/secretmanager.secretAccessor",
    "roles/cloudscheduler.admin",
    "roles/clouddeploy.admin",

    # Database & Storage Roles
    "roles/datastore.user",
    "roles/storage.admin",
    "roles/storage.objectAdmin",
    "roles/cloudsql.admin",

    # Infrastructure & Monitoring Roles
    "roles/compute.admin",
    "roles/logging.admin",
    "roles/monitoring.viewer",
    "roles/monitoring.editor",
    "roles/monitoring.admin",
    "roles/serviceusage.serviceUsageAdmin",

    # Essential Project-Level Roles
    "roles/editor",
    "roles/viewer",
    "roles/iam.serviceAccountUser",
    "roles/serviceusage.serviceUsageConsumer",

    # Security & IAM Roles
    "roles/iam.securityAdmin",
    "roles/iap.httpsResourceAccessor",
  ]

  # Flatten user and role combinations
  user_roles = flatten([
    for user in var.trusted_users : [
      for role in local.devops_roles : {
        user = user
        role = role
      }
    ]
  ])
}

# Grant DevOps roles to trusted users on the agent project
resource "google_project_iam_member" "devops_permissions" {
  for_each = {
    for entry in local.user_roles : "${entry.user}-${entry.role}" => entry
  }

  project = google_project.project.project_id
  role    = each.value.role
  member  = "user:${each.value.user}"
}

# Grant DevOps roles to rad-agent service account (module deployer)
resource "google_project_iam_member" "rad_agent_permissions" {
  for_each = toset(local.devops_roles)

  project = google_project.project.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.rad_agent.email}"
}

# Grant rad-module-creator permission to impersonate rad-agent
# This enables the impersonation chain for deploying to target projects
resource "google_service_account_iam_member" "rad_agent_impersonation" {
  service_account_id = google_service_account.rad_agent.id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.resource_creator_identity}"
  
  depends_on = [
    google_service_account.rad_agent,
    google_project_service.enabled_services  # Ensure IAM API is enabled
  ]
}
