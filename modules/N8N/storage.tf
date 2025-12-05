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
# Cloud Storage Buckets for N8N Binary Data
#########################################################################

resource "google_storage_bucket" "dev_storage" {
  count                       = var.configure_development_environment ? 1 : 0
  name                        = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev"
  location                    = local.region
  force_destroy               = false
  uniform_bucket_level_access = true
  project                     = local.project.project_id
}

resource "google_storage_bucket" "qa_storage" {
  count                       = var.configure_nonproduction_environment ? 1 : 0
  name                        = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-qa"
  location                    = local.region
  force_destroy               = false
  uniform_bucket_level_access = true
  project                     = local.project.project_id
}

resource "google_storage_bucket" "prod_storage" {
  count                       = var.configure_production_environment ? 1 : 0
  name                        = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-prod"
  location                    = local.region
  force_destroy               = false
  uniform_bucket_level_access = true
  project                     = local.project.project_id
}
