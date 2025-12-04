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
resource "google_secret_manager_secret_iam_member" "dev_db_password" {
  count = var.configure_development_environment ? 1 : 0
  project   = local.project.project_id
  secret_id = google_secret_manager_secret.dev_db_password[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n_sa.email}"

  depends_on = [
    google_secret_manager_secret.dev_db_password,
  ]
}

resource "google_secret_manager_secret_iam_member" "dev_encryption_key" {
  count = var.configure_development_environment ? 1 : 0
  project   = local.project.project_id
  secret_id = google_secret_manager_secret.dev_encryption_key[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n_sa.email}"

  depends_on = [
    google_secret_manager_secret.dev_encryption_key,
  ]
}

resource "google_secret_manager_secret_iam_member" "qa_db_password" {
  count = var.configure_nonproduction_environment ? 1 : 0
  project   = local.project.project_id
  secret_id = google_secret_manager_secret.qa_db_password[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n_sa.email}"

  depends_on = [
    google_secret_manager_secret.qa_db_password,
  ]
}

resource "google_secret_manager_secret_iam_member" "qa_encryption_key" {
  count = var.configure_nonproduction_environment ? 1 : 0
  project   = local.project.project_id
  secret_id = google_secret_manager_secret.qa_encryption_key[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n_sa.email}"

  depends_on = [
    google_secret_manager_secret.qa_encryption_key,
  ]
}

resource "google_secret_manager_secret_iam_member" "prod_db_password" {
  count = var.configure_production_environment ? 1 : 0
  project   = local.project.project_id
  secret_id = google_secret_manager_secret.prod_db_password[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n_sa.email}"

  depends_on = [
    google_secret_manager_secret.prod_db_password,
  ]
}

resource "google_secret_manager_secret_iam_member" "prod_encryption_key" {
  count = var.configure_production_environment ? 1 : 0
  project   = local.project.project_id
  secret_id = google_secret_manager_secret.prod_encryption_key[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n_sa.email}"

  depends_on = [
    google_secret_manager_secret.prod_encryption_key,
  ]
}

# Grant Cloud SQL Client role to Cloud Run Service Account
resource "google_project_iam_member" "cloudsql_client" {
  count   = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) ? 1 : 0
  project = local.project.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.n8n_sa.email}"
}
