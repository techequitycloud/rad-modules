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
# Cloud Storage Bucket
#########################################################################

locals {
  # Use provided location or default to the primary region
  storage_location = var.storage_bucket_location != "" ? var.storage_bucket_location : local.region
}

resource "google_storage_bucket" "app_storage" {
  count         = var.create_storage_bucket ? 1 : 0

  project       = local.project.project_id
  name          = "${local.project.project_id}-app-storage-${local.random_id}"
  location      = local.storage_location
  storage_class = var.storage_bucket_storage_class

  uniform_bucket_level_access = true

  versioning {
    enabled = var.storage_bucket_versioning
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 365  # Delete objects older than 1 year
      with_state = "ARCHIVED"
    }
  }

  labels = {
    environment = "production"
    managed-by  = "terraform"
  }

  depends_on = [
    resource.time_sleep.wait_for_apis,
    google_service_account.project_sa_admin,
  ]
}

#########################################################################
# IAM Permissions for Storage Bucket
#########################################################################

# Grant Cloud Run service account access to the bucket
resource "google_storage_bucket_iam_member" "cloudrun_object_admin" {
  count  = var.create_storage_bucket ? 1 : 0

  bucket = google_storage_bucket.app_storage[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.cloudrun_sa_email}"

  depends_on = [
    google_storage_bucket.app_storage,
    google_service_account.cloud_run_sa_admin,
  ]
}

# Grant Cloud Build service account access to the bucket
resource "google_storage_bucket_iam_member" "cloudbuild_object_admin" {
  count  = var.create_storage_bucket ? 1 : 0

  bucket = google_storage_bucket.app_storage[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.cloudbuild_sa_email}"

  depends_on = [
    google_storage_bucket.app_storage,
    google_service_account.cloud_build_sa_admin,
  ]
}

# Grant project service account access to the bucket
resource "google_storage_bucket_iam_member" "project_object_admin" {
  count  = var.create_storage_bucket ? 1 : 0

  bucket = google_storage_bucket.app_storage[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.project_sa_email}"

  depends_on = [
    google_storage_bucket.app_storage,
    google_service_account.project_sa_admin,
  ]
}
