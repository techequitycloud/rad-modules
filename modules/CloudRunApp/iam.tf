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

# Grant Cloud Run service account access to database root password secret
resource "google_secret_manager_secret_iam_member" "root_password" {
  count = local.sql_server_exists ? 1 : 0

  project   = local.project.project_id
  secret_id = "${local.db_instance_name}-root-password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.cloud_run_sa_email}"
}

# Grant Cloud Run service account access to secret environment variables
resource "google_secret_manager_secret_iam_member" "secret_env_vars" {
  for_each = local.secret_environment_variables

  project   = local.project.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.cloud_run_sa_email}"
}

#########################################################################
# IAM permissions for Storage Buckets
#########################################################################

# Grant Cloud Run service account access to storage buckets
resource "google_storage_bucket_iam_member" "bucket_access" {
  for_each = local.create_cloud_storage ? local.storage_buckets : {}

  bucket = google_storage_bucket.buckets[each.key].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.cloud_run_sa_email}"

  depends_on = [
    google_storage_bucket.buckets,
  ]
}

# Grant Cloud Run service account access to bucket metadata (needed for django-storages)
resource "google_storage_bucket_iam_member" "bucket_metadata_access" {
  for_each = local.create_cloud_storage ? local.storage_buckets : {}

  bucket = google_storage_bucket.buckets[each.key].name
  role   = "roles/storage.legacyBucketReader"
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
  secret_id = coalesce(local.github_token_secret, "unused")
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.cloud_build_sa_email}"

  depends_on = [
    data.google_secret_manager_secret.github_token,
  ]
}

# Grant default Cloud Build service account access to GitHub token secret
# (Cloud Build v2 connections use the default service account)
resource "google_secret_manager_secret_iam_member" "github_token_default_sa" {
  count = local.enable_cicd_trigger && local.github_token_secret != null ? 1 : 0

  project   = local.project.project_id
  secret_id = coalesce(local.github_token_secret, "unused")
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:service-${local.project.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"

  depends_on = [
    data.google_secret_manager_secret.github_token,
  ]
}

# Grant Cloud Build service account permission to deploy to Cloud Run
resource "google_project_iam_member" "cloudbuild_run_developer" {
  count = local.enable_cicd_trigger ? 1 : 0

  project = local.project.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${local.cloud_build_sa_email}"
}

# Grant Cloud Build service account permission to act as Cloud Run service account
resource "google_service_account_iam_member" "cloudbuild_sa_user" {
  count = local.enable_cicd_trigger ? 1 : 0

  # Use the full resource ID format (projects/.../serviceAccounts/...)
  service_account_id = local.cloud_run_sa_id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.cloud_build_sa_email}"
}
