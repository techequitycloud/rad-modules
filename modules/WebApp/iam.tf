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
  # Service account name (without @domain)
  cloudrun_sa = "my-cloudrun-sa"
  cloudbuild_sa = "my-cloudbuild-sa"
  
  # Full email addresses
  cloud_run_sa_email = "${local.cloudrun_sa}@${local.project.project_id}.iam.gserviceaccount.com"
  cloudbuild_sa_email = "${local.cloudbuild_sa}@${local.project.project_id}.iam.gserviceaccount.com"
}

#########################################################################
# IAM permissions for Secret Manager
#########################################################################

# Grant Cloud Run service account access to database password secret
resource "google_secret_manager_secret_iam_member" "db_password" {
  count = local.sql_server_exists ? 1 : 0

  project   = local.project.project_id
  secret_id = google_secret_manager_secret.db_password[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.cloud_run_sa_email}"

  depends_on = [
    google_secret_manager_secret.db_password,
  ]
}

# Grant Cloud Run service account access to additional secrets
resource "google_secret_manager_secret_iam_member" "additional_secrets" {
  for_each = google_secret_manager_secret.additional_secrets

  project   = local.project.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.cloud_run_sa_email}"

  depends_on = [
    google_secret_manager_secret.additional_secrets,
  ]
}

#########################################################################
# IAM permissions for Storage Buckets
#########################################################################

# Grant Cloud Run service account access to storage buckets
resource "google_storage_bucket_iam_member" "bucket_access" {
  for_each = var.create_cloud_storage ? local.storage_buckets : {}

  bucket = google_storage_bucket.buckets[each.key].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.cloud_run_sa_email}"

  depends_on = [
    google_storage_bucket.buckets,
  ]
}

#########################################################################
# IAM permissions for CI/CD (Cloud Build)
#########################################################################

# Grant Cloud Build service account access to GitHub token secret
resource "google_secret_manager_secret_iam_member" "github_token" {
  count = local.enable_cicd_trigger && local.github_token_secret != null ? 1 : 0

  project   = local.project.project_id
  secret_id = local.github_token_secret
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.cloudbuild_sa_email}"

  depends_on = [
    data.google_secret_manager_secret.github_token,
  ]
}

# Grant Cloud Build service account permission to deploy to Cloud Run
resource "google_project_iam_member" "cloudbuild_run_developer" {
  count = local.enable_cicd_trigger ? 1 : 0

  project = local.project.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${local.cloudbuild_sa_email}"
}

# Grant Cloud Build service account permission to act as Cloud Run service account
resource "google_service_account_iam_member" "cloudbuild_sa_user" {
  count = local.enable_cicd_trigger ? 1 : 0

  # Use the full email format directly
  service_account_id = local.cloud_run_sa_email
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.cloudbuild_sa_email}"
}
