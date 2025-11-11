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

########################################################################################
# Local variables to check service account existence
########################################################################################

locals {
  # Service account references (existing or newly created)
  cloudbuild_sa_email  = "cloudbuild-sa@${local.project.project_id}.iam.gserviceaccount.com"
  clouddeploy_sa_email = "clouddeploy-sa@${local.project.project_id}.iam.gserviceaccount.com"
  gke_sa_email          = "gke-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloudrun_sa_email    = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloudsql_sa_email    = "cloudsql-sa@${local.project.project_id}.iam.gserviceaccount.com"
  nfsserver_sa_email   = "nfsserver-sa@${local.project.project_id}.iam.gserviceaccount.com"
  setupserver_sa_email = "setupserver-sa@${local.project.project_id}.iam.gserviceaccount.com"
  
  # Service account IDs for IAM bindings
  cloudbuild_sa_id   = "projects/${local.project.project_id}/serviceAccounts/${local.cloudbuild_sa_email}"
  clouddeploy_sa_id  = "projects/${local.project.project_id}/serviceAccounts/${local.clouddeploy_sa_email}"
  gke_sa_id          = "projects/${local.project.project_id}/serviceAccounts/${local.gke_sa_email}"
  cloudrun_sa_id     = "projects/${local.project.project_id}/serviceAccounts/${local.cloudrun_sa_email}"
  cloudsql_sa_id     = "projects/${local.project.project_id}/serviceAccounts/${local.cloudsql_sa_email}"
  nfsserver_sa_id    = "projects/${local.project.project_id}/serviceAccounts/${local.nfsserver_sa_email}"
  setupserver_sa_id  = "projects/${local.project.project_id}/serviceAccounts/${local.setupserver_sa_email}"
}

########################################################################################
# Grant Cloud Build service account permissions to custom service account
########################################################################################

# Service account creation for Cloud Build (only if it doesn't exist)
resource "google_service_account" "cloud_build_sa_admin" {
  project      = local.project.project_id
  account_id   = "cloudbuild-sa"
  display_name = "Cloud Build Service Account"
  description  = "Service account for Cloud Build operations"

  depends_on   = [
    null_resource.api_poll
  ]
}

# IAM permissions for service account on the project (only if SA exists or was created)
resource "google_project_iam_member" "cloud_build_sa" {
  for_each = toset(local.cloud_build_sa_project_roles)

  project  = local.project.project_id          
  member   = "serviceAccount:${local.cloudbuild_sa_email}" 
  role     = each.key                          

  depends_on = [
    null_resource.api_poll,
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.cloud_deploy_sa_admin,
    google_service_account.nfs_server_sa_admin,
    google_service_account.gke_sa_admin,
    google_service_account.cloud_sql_sa_admin,
    google_service_account.setup_server_sa_admin,
  ]
}

locals {
  cloud_build_sa_project_roles = [
    "roles/secretmanager.secretAccessor",
    "roles/cloudbuild.builds.editor",
    "roles/viewer",
    "roles/storage.admin",
    "roles/artifactregistry.reader",
    "roles/artifactregistry.writer",
    "roles/binaryauthorization.attestorsViewer",
    "roles/cloudkms.publicKeyViewer",
    "roles/cloudkms.admin",
    "roles/cloudkms.signerVerifier",
    "roles/containeranalysis.admin",
    "roles/container.admin",
    "roles/iam.serviceAccountUser",
    "roles/clouddeploy.operator",
    "roles/logging.logWriter",
    "roles/run.admin",
    "roles/iam.serviceAccountTokenCreator",
  ]
}

########################################################################################
# Grant Cloud Build service account permissions to default cloud build service account
########################################################################################

# IAM permissions for service account on the project (always enabled as this is for default SA)
resource "google_project_iam_member" "cloud_build_agent_sa" {
  for_each = toset(local.cloud_build_agent_sa_project_roles) 

  project  = local.project.project_id          
  member   = "serviceAccount:${local.project_number}@cloudbuild.gserviceaccount.com" 
  role     = each.key                          

  depends_on = [
    null_resource.api_poll,
    google_service_account.project_sa_admin,
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.cloud_deploy_sa_admin,
    google_service_account.nfs_server_sa_admin,
    google_service_account.gke_sa_admin,
    google_service_account.cloud_sql_sa_admin,
    google_service_account.setup_server_sa_admin,
  ]
}

locals {
  cloud_build_agent_sa_project_roles = [
    "roles/secretmanager.secretAccessor",
    "roles/artifactregistry.reader",
    "roles/binaryauthorization.attestorsViewer",
    "roles/cloudkms.publicKeyViewer",
    "roles/cloudkms.admin",
    "roles/cloudkms.signerVerifier",
    "roles/containeranalysis.admin",
    "roles/container.admin",
    "roles/iam.serviceAccountUser",
    "roles/clouddeploy.operator",
    "roles/run.admin",
  ]
}

#########################################################################
# Service account creation for Cloud Deploy
#########################################################################

resource "google_service_account" "cloud_deploy_sa_admin" {
  project      = local.project.project_id
  account_id   = "clouddeploy-sa"
  display_name = "Cloud Deploy Service Account"
  description  = "Service account for Cloud Deploy operations"

  depends_on   = [
    null_resource.api_poll
  ]
}

# IAM permissions for service account on the project (only if SA exists or was created)
resource "google_project_iam_member" "cloud_deploy_sa" {
  for_each = toset(local.cloud_deploy_sa_project_roles)

  project  = local.project.project_id          
  member   = "serviceAccount:${local.clouddeploy_sa_email}" 
  role     = each.key                          

  depends_on = [
    null_resource.api_poll,
    google_service_account.project_sa_admin,
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.cloud_deploy_sa_admin,
    google_service_account.nfs_server_sa_admin,
    google_service_account.gke_sa_admin,
    google_service_account.cloud_sql_sa_admin,
    google_service_account.setup_server_sa_admin,
  ]
}

locals {
  cloud_deploy_sa_project_roles = [
    "roles/artifactregistry.reader",
    "roles/iam.serviceAccountUser",
    "roles/clouddeploy.jobRunner",
    "roles/clouddeploy.releaser",
    "roles/cloudbuild.builds.editor",
    "roles/storage.objectAdmin",
    "roles/run.admin",
    "roles/container.developer",
  ]
}

#########################################################################
# GCP project service account (Used by GKE)
#########################################################################

# Service account for GCP identity within Kubernetes
resource "google_service_account" "gke_sa_admin" {
  project      = local.project.project_id
  account_id   = "gke-sa"        # Account ID for the service account
  description  = "Service account for GKE cluster operations"
  display_name = "GKE Service Account"      # Display name for the service account

  depends_on = [
    null_resource.api_poll               # Dependency on a time delay, ensuring it's created after a certain time period
  ]
}

# IAM permissions for service account on the project (only if SA exists or was created)
resource "google_project_iam_member" "gke_sa" {
  for_each = toset(local.gke_sa_project_roles) 

  project  = local.project.project_id          
  member   = "serviceAccount:${local.gke_sa_email}" 
  role     = each.key                          

  depends_on = [
    null_resource.api_poll,
    google_service_account.project_sa_admin,
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.cloud_deploy_sa_admin,
    google_service_account.nfs_server_sa_admin,
    google_service_account.gke_sa_admin,
    google_service_account.cloud_sql_sa_admin,
    google_service_account.setup_server_sa_admin,
  ]
}

locals {
  gke_sa_project_roles = [
    "roles/storage.objectAdmin",
    "roles/storage.objectViewer",
    "roles/artifactregistry.reader",
    "roles/storage.admin",
    "roles/monitoring.viewer",
    "roles/logging.logWriter",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/container.defaultNodeServiceAccount",
    "roles/monitoring.metricWriter",
    "roles/compute.networkUser",
  ]
}

#########################################################################
# Cloud Run service resources
#########################################################################

# Service account creation for Cloud Run
resource "google_service_account" "cloud_run_sa_admin" {
  project      = local.project.project_id
  account_id   = "cloudrun-sa"
  display_name = "Cloud Run Service Account"
  description  = "Service account for Cloud Run operations"

  depends_on   = [
    null_resource.api_poll
  ]
}

locals {
  cloud_run_sa_project_roles = [
    "roles/compute.networkUser",
    "roles/run.admin",
    "roles/secretmanager.secretAccessor",
    "roles/storage.objectUser",
  ]
}

# IAM permissions for service account on the project (only if SA exists or was created)
resource "google_project_iam_member" "cloud_run_sa" {
  for_each = toset(local.cloud_run_sa_project_roles)

  project  = local.project.project_id          
  member   = "serviceAccount:${local.cloudrun_sa_email}" 
  role     = each.key                          

  depends_on = [
    null_resource.api_poll,
    google_service_account.project_sa_admin,
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.cloud_deploy_sa_admin,
    google_service_account.nfs_server_sa_admin,
    google_service_account.gke_sa_admin,
    google_service_account.cloud_sql_sa_admin,
    google_service_account.setup_server_sa_admin,
  ]
}

# Grant the Cloud Run service agent access to the Shared VPC (always enabled as this is for default SA)
resource "google_project_iam_member" "cloudrun_agent_shared_vpc_access" {
  project = var.existing_project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:service-${local.project_number}@serverless-robot-prod.iam.gserviceaccount.com"

  depends_on   = [
    null_resource.api_poll,
    google_service_account.project_sa_admin,
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.cloud_deploy_sa_admin,
    google_service_account.nfs_server_sa_admin,
    google_service_account.gke_sa_admin,
    google_service_account.cloud_sql_sa_admin,
    google_service_account.setup_server_sa_admin,
  ]
}

#########################################################################
# Service Account creation to connect to Cloud SQL
#########################################################################

resource "google_service_account" "cloud_sql_sa_admin" {
  project      = local.project.project_id
  account_id   = "cloudsql-sa"
  display_name = "Service Account to connect Cloud SQL"
  description  = "Service account for Cloud SQL operations"

  # This service account should be created after a certain delay to ensure dependencies are ready
  depends_on = [
    null_resource.api_poll
  ]
}

locals {
  cloud_sql_sa_project_roles = [
    "roles/storage.admin",
    "roles/cloudsql.client",
  ]
}

# IAM permissions for service account on the project (only if SA exists or was created)
resource "google_project_iam_member" "cloud_sql_sa" {
  for_each = toset(local.cloud_sql_sa_project_roles)

  project  = local.project.project_id          
  member   = "serviceAccount:${local.cloudsql_sa_email}" 
  role     = each.key                         

  depends_on = [
    null_resource.api_poll,
    google_service_account.project_sa_admin,
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.cloud_deploy_sa_admin,
    google_service_account.nfs_server_sa_admin,
    google_service_account.gke_sa_admin,
    google_service_account.cloud_sql_sa_admin,
    google_service_account.setup_server_sa_admin,
  ]
}

#########################################################################
# NFS service resources
#########################################################################

# Create a service account for NFS server with a dependency on a wait period
resource "google_service_account" "nfs_server_sa_admin" {
  project      = local.project.project_id              # Reference to the project ID from local variables
  account_id   = "nfsserver-sa"                        # Unique ID for the service account
  display_name = "NFS Server Service Account"          # Human-readable name for the service account
  description  = "Service account for NFS server operations"
  
  # Ensures that creation of the service account waits for a specific time period
  depends_on  = [
    null_resource.api_poll
  ]
}

# List of roles assigned to the NFS service account within the project
locals {
  nfs_server_sa_project_roles = [
    "roles/storage.admin",
    "roles/logging.logWriter",
  ]
}

# IAM permissions for service account on the project (only if SA exists or was created)
resource "google_project_iam_member" "nfs_server_sa" {
  for_each = toset(local.nfs_server_sa_project_roles)

  project  = local.project.project_id          # The project ID
  member   = "serviceAccount:${local.nfsserver_sa_email}" # Adjusted to reference the first service account
  role     = each.key                          # Use each.key instead of each.value

  # Ensures that this resource is created
  depends_on = [
    null_resource.api_poll,
    google_service_account.project_sa_admin,
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.cloud_deploy_sa_admin,
    google_service_account.cloud_sql_sa_admin,
    google_service_account.gke_sa_admin,
    google_service_account.nfs_server_sa_admin,
    google_service_account.setup_server_sa_admin,
  ]
}

#########################################################################
# Service Account creation for Setup Server
#########################################################################

resource "google_service_account" "setup_server_sa_admin" {
  project      = local.project.project_id
  account_id   = "setupserver-sa"
  display_name = "Service Account for Setup Server"
  description  = "Service account for setup server operations"

  # This service account should be created after a certain delay to ensure dependencies are ready
  depends_on = [
    null_resource.api_poll
  ]
}

# List of roles assigned to the setup server service account within the project
locals {
  setup_server_sa_project_roles = [
    "roles/compute.instanceAdmin.v1",
    "roles/compute.viewer",
    "roles/storage.admin",
    "roles/logging.logWriter",
    "roles/container.admin",
    "roles/container.clusterViewer",
    "roles/iam.serviceAccountUser",
    "roles/cloudsql.client",
    "roles/iap.tunnelResourceAccessor",
  ]
}

# IAM permissions for service account on the project (only if SA exists or was created)
resource "google_project_iam_member" "setup_server_sa" {
  for_each = toset(local.setup_server_sa_project_roles)

  project  = local.project.project_id          # The project ID
  member   = "serviceAccount:${local.setupserver_sa_email}" # Adjusted to reference the first service account
  role     = each.key                          # Use each.key instead of each.value

  # Ensures that this resource is created
  depends_on = [
    null_resource.api_poll,
    google_service_account.project_sa_admin,
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.cloud_deploy_sa_admin,
    google_service_account.nfs_server_sa_admin,
    google_service_account.cloud_sql_sa_admin,
    google_service_account.gke_sa_admin,
    google_service_account.setup_server_sa_admin,
  ]
}
