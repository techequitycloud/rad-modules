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
