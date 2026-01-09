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

#########################################################################
# Cloud Run service resources
#########################################################################

# IAM member resource to grant the service account access to the secret in Secret Manager
resource "google_secret_manager_secret_iam_member" "db_password" {
  count     = var.configure_environment ? 1 : 0
  project   = local.project.project_id
  secret_id = google_secret_manager_secret.db_password[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"

  # Dependency to ensure the secret exists before this resource is created
  depends_on = [
    google_secret_manager_secret.db_password,
  ]
}

#########################################################################
# IAM permissions for impersonated service account
#########################################################################

# Note: roles/compute.osLoginExternalUser cannot be granted at project level
# It requires organization-level permissions. Since we're using IAP tunneling
# and metadata-based SSH, we don't need this role.

# Grant Compute Instance Admin role for listing and managing instances
resource "google_project_iam_member" "impersonation_compute_admin" {
  count   = local.impersonation_service_account != "" ? 1 : 0
  project = local.project.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${local.impersonation_service_account}"
}

# Grant IAP Tunnel User role for IAP tunneling (required when no external IP)
resource "google_project_iam_member" "impersonation_iap_tunnel" {
  count   = local.impersonation_service_account != "" ? 1 : 0
  project = local.project.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = "serviceAccount:${local.impersonation_service_account}"
}

# Grant Service Account User role to allow acting as the service account
resource "google_project_iam_member" "impersonation_sa_user" {
  count   = local.impersonation_service_account != "" ? 1 : 0
  project = local.project.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${local.impersonation_service_account}"
}

# Grant Compute Viewer role for listing compute resources
resource "google_project_iam_member" "impersonation_compute_viewer" {
  count   = local.impersonation_service_account != "" ? 1 : 0
  project = local.project.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${local.impersonation_service_account}"
}

# Grant Compute OS Admin Login role for SSH access via metadata
resource "google_project_iam_member" "impersonation_os_admin_login" {
  count   = local.impersonation_service_account != "" ? 1 : 0
  project = local.project.project_id
  role    = "roles/compute.osAdminLogin"
  member  = "serviceAccount:${local.impersonation_service_account}"
}
