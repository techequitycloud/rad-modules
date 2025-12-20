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

# Local variables for bucket names
locals {
  # Bucket names
  data_bucket_name = "${var.application_name}${var.tenant_deployment_id}${local.random_id}-data"
}

resource "google_storage_bucket" "gcs_private_data_bucket" {
  count = var.create_cloud_storage ? 1 : 0
  
  name          = local.data_bucket_name
  location      = "EU"
  project       = local.project.project_id
  force_destroy = true
}

data "google_storage_bucket" "data_bucket" {
  count = var.create_cloud_storage ? 1 : 0
  name  = local.data_bucket_name
  
  depends_on = [
    google_storage_bucket.gcs_private_data_bucket
  ]
}
