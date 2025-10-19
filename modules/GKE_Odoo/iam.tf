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
# Kubernetes service resources
#########################################################################

# IAM member resource to grant the service account access to the secret in Secret Manager
resource "google_secret_manager_secret_iam_member" "dev_db_password" {
  count     = local.sql_server_exists && local.gke_sa_exists ? 1 : 0  
  project   = local.project.project_id
  secret_id = local.sql_server_exists ? google_secret_manager_secret.dev_db_password[0].secret_id : null
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.gke_sa_email}"

  depends_on = [
    time_sleep.wait_90_seconds,
  ]
}

# IAM member resource to grant the service account access to the secret in Secret Manager
resource "google_secret_manager_secret_iam_member" "qa_db_password" {
  count     = local.sql_server_exists && local.gke_sa_exists ? 1 : 0  
  project   = local.project.project_id
  secret_id = local.sql_server_exists ? google_secret_manager_secret.qa_db_password[0].secret_id : null
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.gke_sa_email}"

  depends_on = [
    time_sleep.wait_90_seconds,
  ]
}

# IAM member resource to grant the service account access to the secret in Secret Manager
resource "google_secret_manager_secret_iam_member" "prod_db_password" {
  count     = local.sql_server_exists && local.gke_sa_exists ? 1 : 0  
  project   = local.project.project_id
  secret_id = local.sql_server_exists ? google_secret_manager_secret.prod_db_password[0].secret_id : null
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.gke_sa_email}"

  depends_on = [
    time_sleep.wait_90_seconds,
  ]
}

resource "google_service_account_iam_member" "k8s_dev_identity" {
  for_each           = local.gke_sa_exists ? toset(local.gke_sa_workload_identity_role) : toset([])
  member             = "serviceAccount:${local.project.project_id}.svc.id.goog[app${var.application_name}${local.random_id}dev/${var.application_name}${var.tenant_deployment_id}dev]" 
  role               = each.key
  service_account_id = "projects/${local.project.project_id}/serviceAccounts/${local.gke_sa_email}"
}

# IAM policy binding for Kubernetes workload identity user
resource "google_service_account_iam_member" "k8s_qa_identity" {
  for_each           = local.gke_sa_exists ? toset(local.gke_sa_workload_identity_role) : toset([])
  member             = "serviceAccount:${local.project.project_id}.svc.id.goog[app${var.application_name}${local.random_id}qa/${var.application_name}${var.tenant_deployment_id}qa]" 
  role               = each.key 
  service_account_id = "projects/${local.project.project_id}/serviceAccounts/${local.gke_sa_email}"
}

# IAM policy binding for Kubernetes workload identity user
resource "google_service_account_iam_member" "k8s_prod_identity" {
  for_each           = local.gke_sa_exists ? toset(local.gke_sa_workload_identity_role) : toset([])
  member             = "serviceAccount:${local.project.project_id}.svc.id.goog[app${var.application_name}${local.random_id}prod/${var.application_name}${var.tenant_deployment_id}prod]"
  role               = each.key 
  service_account_id = "projects/${local.project.project_id}/serviceAccounts/${local.gke_sa_email}"
}

locals {
  gke_sa_workload_identity_role = [
    "roles/iam.workloadIdentityUser",
  ]
}

resource "google_storage_bucket_iam_member" "k8s_gcs_access" {
  count  = var.create_cloud_storage ? 1 : 0  
  bucket = local.backup_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${local.gke_sa_email}"

  depends_on = [
    google_storage_bucket.gcs_private_backup_bucket,
  ]
}

# Ref: https://github.com/GoogleCloudPlatform/gcs-fuse-csi-driver/blob/main/docs/authentication.md

resource "google_storage_bucket_iam_binding" "gcs_fuse_bucket_iam_binding" {
  count   = var.create_cloud_storage ? 1 : 0  
  bucket  = local.backup_bucket_name
  role    = "roles/storage.objectUser"
  members = [
    "principal://iam.googleapis.com/projects/${local.project_number}/locations/global/workloadIdentityPools/${local.project.project_id}.svc.id.goog/subject/ns/${var.application_name}${var.tenant_deployment_id}dev/sa/app${var.application_name}${local.random_id}dev",
    "principal://iam.googleapis.com/projects/${local.project_number}/locations/global/workloadIdentityPools/${local.project.project_id}.svc.id.goog/subject/ns/${var.application_name}${var.tenant_deployment_id}qa/sa/app${var.application_name}${local.random_id}qa",
    "principal://iam.googleapis.com/projects/${local.project_number}/locations/global/workloadIdentityPools/${local.project.project_id}.svc.id.goog/subject/ns/${var.application_name}${var.tenant_deployment_id}prod/sa/app${var.application_name}${local.random_id}prod"
  ]

  depends_on = [
    google_service_account_iam_member.k8s_dev_identity,
    google_service_account_iam_member.k8s_qa_identity,
    google_service_account_iam_member.k8s_prod_identity,
    google_storage_bucket.gcs_private_backup_bucket,
  ]
}

# Resource to introduce a delay in the Terraform apply operation.
resource "time_sleep" "wait_90_seconds" {
  create_duration = "90s" 

  depends_on = [
    google_secret_manager_secret.dev_db_password,
    google_secret_manager_secret.qa_db_password,
    google_secret_manager_secret.prod_db_password,
  ]
}