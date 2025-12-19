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

# IAM member resource to grant the service account access to the database password secret in Secret Manager
resource "google_secret_manager_secret_iam_member" "db_password" {
  count = var.configure_environment ? 1 : 0
  project   = local.project.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"

  # Dependency to ensure the secret exists before this resource is created
  depends_on = [
    google_secret_manager_secret.db_password,
  ]
}

# IAM member resource to grant the service account access to the OpenEMR admin password secret in Secret Manager
resource "google_secret_manager_secret_iam_member" "openemr_admin_password" {
  count = var.configure_environment ? 1 : 0
  project   = local.project.project_id
  secret_id = google_secret_manager_secret.openemr_admin_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"

  # Dependency to ensure the secret exists before this resource is created
  depends_on = [
    google_secret_manager_secret.openemr_admin_password,
  ]
}

