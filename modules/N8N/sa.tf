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
# Create Service Account
#########################################################################

resource "google_service_account" "n8n_sa" {
  account_id   = "n8n-sa-${var.tenant_deployment_id}"
  display_name = "n8n Service Account"
  project      = local.project.project_id
}

resource "google_storage_hmac_key" "n8n_key" {
  service_account_email = google_service_account.n8n_sa.email
  project               = local.project.project_id
}

resource "google_project_iam_member" "cloudsql_client" {
  project = local.project.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.n8n_sa.email}"
}

resource "google_project_iam_member" "secret_accessor" {
  project = local.project.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.n8n_sa.email}"
}

locals {
  project_sa_email      = "project-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloud_build_sa_email  = "cloudbuild-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloud_deploy_sa_email = "clouddeploy-sa@${local.project.project_id}.iam.gserviceaccount.com"
  gke_sa_email          = "gke-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloud_run_sa_email    = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloud_sql_sa_email    = "cloudsql-sa@${local.project.project_id}.iam.gserviceaccount.com"
  nfs_server_sa_email   = "nfsserver-sa@${local.project.project_id}.iam.gserviceaccount.com"
  setup_server_sa_email = "setupserver-sa@${local.project.project_id}.iam.gserviceaccount.com"
}
