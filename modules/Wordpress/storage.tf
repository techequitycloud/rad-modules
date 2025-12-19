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

# Local variables for bucket existence
locals {
  env_suffix = "-dev"

  # Bucket names
  backup_bucket_name = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}${local.env_suffix}-backups"
  data_bucket_name = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}${local.env_suffix}-data"
  restore_bucket_name = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}${local.env_suffix}-restore"
}

# Create buckets only if they don't exist and creation is requested
resource "google_storage_bucket" "gcs_private_backup_bucket" {
  count = var.create_cloud_storage ? 1 : 0
  
  name          = local.backup_bucket_name
  location      = "EU"
  project       = local.project.project_id
  force_destroy = true
}

resource "google_storage_bucket" "gcs_private_data_bucket" {
  count = var.create_cloud_storage ? 1 : 0
  
  name          = local.data_bucket_name
  location      = "EU"
  project       = local.project.project_id
  force_destroy = true
}

resource "google_storage_bucket" "gcs_private_restore_bucket" {
  count = var.create_cloud_storage ? 1 : 0
  
  name          = local.restore_bucket_name
  location      = "EU"
  project       = local.project.project_id
  force_destroy = true
}

# Data sources to get bucket information (whether existing or newly created)
data "google_storage_bucket" "backup_bucket" {
  count = var.create_cloud_storage ? 1 : 0
  name  = local.backup_bucket_name
  
  depends_on = [
    google_storage_bucket.gcs_private_backup_bucket
  ]
}

data "google_storage_bucket" "data_bucket" {
  count = var.create_cloud_storage ? 1 : 0
  name  = local.data_bucket_name
  
  depends_on = [
    google_storage_bucket.gcs_private_data_bucket
  ]
}

data "google_storage_bucket" "restore_bucket" {
  count = var.create_cloud_storage ? 1 : 0
  name  = local.restore_bucket_name
  
  depends_on = [
    google_storage_bucket.gcs_private_restore_bucket
  ]
}
