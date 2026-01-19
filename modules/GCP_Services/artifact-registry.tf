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
# Artifact Registry Repository for Container Images
#########################################################################

resource "google_artifact_registry_repository" "container_repo" {
  count         = var.enable_cicd ? 1 : 0

  project       = local.project.project_id
  location      = local.region
  repository_id = "app-containers-${local.random_id}"
  description   = "Container image repository for CI/CD pipeline"
  format        = var.artifact_registry_format
  mode          = var.artifact_registry_mode

  labels = {
    environment = "production"
    managed-by  = "terraform"
    cicd        = "enabled"
  }

  depends_on = [
    resource.time_sleep.wait_for_apis,
    google_service_account.project_sa_admin,
    google_service_account.cloud_build_sa_admin,
  ]
}

#########################################################################
# IAM Permissions for Artifact Registry
#########################################################################

# Grant Cloud Build service account write access
resource "google_artifact_registry_repository_iam_member" "cloudbuild_writer" {
  count      = var.enable_cicd ? 1 : 0

  project    = local.project.project_id
  location   = local.region
  repository = google_artifact_registry_repository.container_repo[0].name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${local.cloudbuild_sa_email}"

  depends_on = [
    google_artifact_registry_repository.container_repo,
    google_service_account.cloud_build_sa_admin,
  ]
}

# Grant default Cloud Build service account write access
resource "google_artifact_registry_repository_iam_member" "default_cloudbuild_writer" {
  count      = var.enable_cicd ? 1 : 0

  project    = local.project.project_id
  location   = local.region
  repository = google_artifact_registry_repository.container_repo[0].name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${local.project_number}@cloudbuild.gserviceaccount.com"

  depends_on = [
    google_artifact_registry_repository.container_repo,
  ]
}

# Grant Cloud Run service account read access
resource "google_artifact_registry_repository_iam_member" "cloudrun_reader" {
  count      = var.enable_cicd ? 1 : 0

  project    = local.project.project_id
  location   = local.region
  repository = google_artifact_registry_repository.container_repo[0].name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${local.cloudrun_sa_email}"

  depends_on = [
    google_artifact_registry_repository.container_repo,
    google_service_account.cloud_run_sa_admin,
  ]
}

# Grant project service account admin access
resource "google_artifact_registry_repository_iam_member" "project_admin" {
  count      = var.enable_cicd ? 1 : 0

  project    = local.project.project_id
  location   = local.region
  repository = google_artifact_registry_repository.container_repo[0].name
  role       = "roles/artifactregistry.admin"
  member     = "serviceAccount:${local.project_sa_email}"

  depends_on = [
    google_artifact_registry_repository.container_repo,
    google_service_account.project_sa_admin,
  ]
}

#########################################################################
# Store GitHub Token in Secret Manager
#########################################################################

resource "google_secret_manager_secret" "github_token" {
  count      = var.enable_cicd && var.github_token != "" ? 1 : 0

  project    = local.project.project_id
  secret_id  = "github-token-${local.random_id}"

  replication {
    auto {}
  }

  labels = {
    managed-by = "terraform"
    purpose    = "github-access"
  }

  depends_on = [
    resource.time_sleep.wait_for_apis,
  ]
}

resource "google_secret_manager_secret_version" "github_token" {
  count       = var.enable_cicd && var.github_token != "" ? 1 : 0

  secret      = google_secret_manager_secret.github_token[0].id
  secret_data = var.github_token

  depends_on = [
    google_secret_manager_secret.github_token,
  ]
}

# Grant Cloud Build access to the GitHub token
resource "google_secret_manager_secret_iam_member" "cloudbuild_secret_accessor" {
  count      = var.enable_cicd && var.github_token != "" ? 1 : 0

  project    = local.project.project_id
  secret_id  = google_secret_manager_secret.github_token[0].secret_id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${local.cloudbuild_sa_email}"

  depends_on = [
    google_secret_manager_secret.github_token,
    google_service_account.cloud_build_sa_admin,
  ]
}

# Grant default Cloud Build service account access to secret
resource "google_secret_manager_secret_iam_member" "default_cloudbuild_secret_accessor" {
  count      = var.enable_cicd && var.github_token != "" ? 1 : 0

  project    = local.project.project_id
  secret_id  = google_secret_manager_secret.github_token[0].secret_id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${local.project_number}@cloudbuild.gserviceaccount.com"

  depends_on = [
    google_secret_manager_secret.github_token,
  ]
}
