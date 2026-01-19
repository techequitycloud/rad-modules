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
# Artifact Registry Repository
#########################################################################

resource "google_artifact_registry_repository" "main" {
  count         = var.create_artifact_registry ? 1 : 0

  project       = local.project.project_id
  location      = local.region
  repository_id = "app-images-${local.random_id}"
  description   = "Docker image repository for application containers"
  format        = var.artifact_registry_format
  mode          = var.artifact_registry_mode

  labels = {
    environment = "production"
    managed-by  = "terraform"
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

# Grant Cloud Build service account access to push images
resource "google_artifact_registry_repository_iam_member" "cloudbuild_writer" {
  count      = var.create_artifact_registry ? 1 : 0

  project    = local.project.project_id
  location   = local.region
  repository = google_artifact_registry_repository.main[0].name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${local.cloudbuild_sa_email}"

  depends_on = [
    google_artifact_registry_repository.main,
    google_service_account.cloud_build_sa_admin,
  ]
}

# Grant Cloud Run service account access to pull images
resource "google_artifact_registry_repository_iam_member" "cloudrun_reader" {
  count      = var.create_artifact_registry ? 1 : 0

  project    = local.project.project_id
  location   = local.region
  repository = google_artifact_registry_repository.main[0].name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${local.cloudrun_sa_email}"

  depends_on = [
    google_artifact_registry_repository.main,
    google_service_account.cloud_run_sa_admin,
  ]
}

# Grant default Cloud Build service account access
resource "google_artifact_registry_repository_iam_member" "default_cloudbuild_writer" {
  count      = var.create_artifact_registry ? 1 : 0

  project    = local.project.project_id
  location   = local.region
  repository = google_artifact_registry_repository.main[0].name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${local.project_number}@cloudbuild.gserviceaccount.com"

  depends_on = [
    google_artifact_registry_repository.main,
  ]
}
