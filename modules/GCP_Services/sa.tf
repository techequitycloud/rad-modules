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
  cloudrun_sa_email    = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
  nfsserver_sa_email   = "nfsserver-sa@${local.project.project_id}.iam.gserviceaccount.com"
  
  # Service account IDs for IAM bindings
  cloudbuild_sa_id   = "projects/${local.project.project_id}/serviceAccounts/${local.cloudbuild_sa_email}"
  cloudrun_sa_id     = "projects/${local.project.project_id}/serviceAccounts/${local.cloudrun_sa_email}"
  nfsserver_sa_id    = "projects/${local.project.project_id}/serviceAccounts/${local.nfsserver_sa_email}"
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
}

# IAM permissions for service account on the project (only if SA exists or was created)
resource "google_project_iam_member" "cloud_build_sa" {
  for_each = toset(local.cloud_build_sa_project_roles)

  project  = local.project.project_id          
  member   = "serviceAccount:${local.cloudbuild_sa_email}" 
  role     = each.key                          

  depends_on = [
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.nfs_server_sa_admin,
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
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.nfs_server_sa_admin,
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
# Cloud Run service resources
#########################################################################

# Service account creation for Cloud Run
resource "google_service_account" "cloud_run_sa_admin" {
  project      = local.project.project_id
  account_id   = "cloudrun-sa"
  display_name = "Cloud Run Service Account"
  description  = "Service account for Cloud Run operations"
}

locals {
  cloud_run_sa_project_roles = [
    "roles/compute.networkUser",
    "roles/run.admin",
    "roles/secretmanager.secretAccessor",
    "roles/storage.objectUser",
    "roles/storage.objectAdmin",        # For storage bucket access
    "roles/cloudsql.client",            # For Cloud SQL connection (CRITICAL)
    "roles/vpcaccess.user",             # For VPC Connector access
  ]
}

# IAM permissions for service account on the project (only if SA exists or was created)
resource "google_project_iam_member" "cloud_run_sa" {
  for_each = toset(local.cloud_run_sa_project_roles)

  project  = local.project.project_id          
  member   = "serviceAccount:${local.cloudrun_sa_email}" 
  role     = each.key                          

  depends_on = [
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.nfs_server_sa_admin,
  ]
}

# Grant the Cloud Run service agent access to the Shared VPC (always enabled as this is for default SA)
resource "google_project_iam_member" "cloudrun_agent_shared_vpc_access" {
  project = var.existing_project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:service-${local.project_number}@serverless-robot-prod.iam.gserviceaccount.com"

  depends_on = [
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.nfs_server_sa_admin,
  ]
}

# Grant VPC Access User role to Cloud Run service agent
resource "google_project_iam_member" "cloudrun_agent_vpc_access" {
  project = var.existing_project_id
  role    = "roles/vpcaccess.user"
  member  = "serviceAccount:service-${local.project_number}@serverless-robot-prod.iam.gserviceaccount.com"

  depends_on = [
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.nfs_server_sa_admin,
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
}

# List of roles assigned to the NFS service account within the project
locals {
  nfs_server_sa_project_roles = [
    "roles/storage.admin",
    "roles/logging.logWriter",
    "roles/compute.instanceAdmin.v1",   # For managing NFS instances
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
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.nfs_server_sa_admin,
  ]
}

#########################################################################
# Service Networking Agent (for Private Service Connect)
# Required for Cloud SQL, Memorystore, and other managed services
#########################################################################

# Get project details dynamically
data "google_project" "current" {
  project_id = var.existing_project_id
}

# Grant Service Networking Agent role (required for creating VPC peering)
resource "google_project_iam_member" "servicenetworking_agent" {
  project = var.existing_project_id
  role    = "roles/servicenetworking.serviceAgent"
  member  = "serviceAccount:service-${data.google_project.current.number}@service-networking.iam.gserviceaccount.com"

  depends_on = [
    time_sleep.wait_for_apis
  ]
}

# Grant Compute Network Admin role (required for listing global addresses)
resource "google_project_iam_member" "servicenetworking_network_admin" {
  project = var.existing_project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:service-${data.google_project.current.number}@service-networking.iam.gserviceaccount.com"

  depends_on = [
    time_sleep.wait_for_apis
  ]
}

# Additional permission for global address management
resource "google_project_iam_member" "servicenetworking_compute_admin" {
  project = var.existing_project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:service-${data.google_project.current.number}@service-networking.iam.gserviceaccount.com"

  depends_on = [
    time_sleep.wait_for_apis
  ]
}

# Wait for IAM permissions to propagate before creating service networking connection
resource "time_sleep" "wait_for_servicenetworking_iam" {
  create_duration = "45s"

  depends_on = [
    google_project_iam_member.servicenetworking_agent,
    google_project_iam_member.servicenetworking_network_admin,
    google_project_iam_member.servicenetworking_compute_admin
  ]
}
