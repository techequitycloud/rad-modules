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
  project   = local.project.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.cloud_run_sa_email}"

  # Dependency to ensure the secret exists before this resource is created
  depends_on = [
    google_secret_manager_secret.db_password,
  ]
}

#########################################################################
# IAM permissions for impersonated service account
#########################################################################

# Note: Since we removed NFS dependency and no longer SSH into compute instances,
# compute-related IAM roles (instanceAdmin, iap.tunnelResourceAccessor,
# compute.viewer, osAdminLogin) have been removed. Cloud Build handles its own
# IAM permissions automatically.
