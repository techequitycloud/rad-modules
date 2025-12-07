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
# Use external data source to check service account existence
########################################################################################

data "external" "check_service_accounts" {
  program = ["bash", "-c", <<-EOT
    PROJECT_ID="${local.project.project_id}"
    if [ -n "${var.resource_creator_identity}" ]; then
      SA_ARG="--impersonate-service-account=${var.resource_creator_identity}"
    fi
    
    # Function to check if service account exists
    check_sa() {
      local sa_id="$1"
      if gcloud iam service-accounts describe "$sa_id@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" $SA_ARG >/dev/null 2>&1; then
        echo "true"
      else
        echo "false"
      fi
    }
    
    # Check all service accounts
    PROJECT_SA_EXISTS=$(check_sa "${local.project.project_id}")
    CLOUD_BUILD_SA_EXISTS=$(check_sa "cloudbuild-sa")
    CLOUD_DEPLOY_SA_EXISTS=$(check_sa "clouddeploy-sa")
    GKE_SA_EXISTS=$(check_sa "gke-sa")
    CLOUD_RUN_SA_EXISTS=$(check_sa "cloudrun-sa")
    CLOUD_SQL_SA_EXISTS=$(check_sa "cloudsql-sa")
    NFS_SERVER_SA_EXISTS=$(check_sa "nfsserver-sa")
    SETUP_SERVER_SA_EXISTS=$(check_sa "setupserver-sa")
    
    # Output JSON
    cat <<EOF
{
  "project_sa_exists": "$PROJECT_SA_EXISTS",
  "cloud_build_sa_exists": "$CLOUD_BUILD_SA_EXISTS",
  "cloud_deploy_sa_exists": "$CLOUD_DEPLOY_SA_EXISTS",
  "gke_sa_exists": "$GKE_SA_EXISTS",
  "cloud_run_sa_exists": "$CLOUD_RUN_SA_EXISTS",
  "cloud_sql_sa_exists": "$CLOUD_SQL_SA_EXISTS",
  "nfs_server_sa_exists": "$NFS_SERVER_SA_EXISTS",
  "setup_server_sa_exists": "$SETUP_SERVER_SA_EXISTS"
}
EOF
  EOT
  ]
}

########################################################################################
# Local variables to check service account existence
########################################################################################

locals {

  # Parse the results from external data source
  project_sa_exists      = data.external.check_service_accounts.result["project_sa_exists"] == "true"
  cloud_build_sa_exists  = data.external.check_service_accounts.result["cloud_build_sa_exists"] == "true"
  cloud_deploy_sa_exists = data.external.check_service_accounts.result["cloud_deploy_sa_exists"] == "true"
  gke_sa_exists          = data.external.check_service_accounts.result["gke_sa_exists"] == "true"
  cloud_run_sa_exists    = data.external.check_service_accounts.result["cloud_run_sa_exists"] == "true"
  cloud_sql_sa_exists    = data.external.check_service_accounts.result["cloud_sql_sa_exists"] == "true"
  nfs_server_sa_exists   = data.external.check_service_accounts.result["nfs_server_sa_exists"] == "true"
  setup_server_sa_exists = data.external.check_service_accounts.result["setup_server_sa_exists"] == "true"

  # Service account references (existing or newly created)
  project_sa_email      = "project-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloud_build_sa_email  = "cloudbuild-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloud_deploy_sa_email = "clouddeploy-sa@${local.project.project_id}.iam.gserviceaccount.com"
  gke_sa_email          = "gke-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloud_run_sa_email    = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloud_sql_sa_email    = "cloudsql-sa@${local.project.project_id}.iam.gserviceaccount.com"
  nfs_server_sa_email   = "nfsserver-sa@${local.project.project_id}.iam.gserviceaccount.com"
  setup_server_sa_email = "setupserver-sa@${local.project.project_id}.iam.gserviceaccount.com"

  project_sa_id           = "projects/${local.project.project_id}/serviceAccounts/project-sa@${local.project.project_id}.iam.gserviceaccount.com"
}

########################################################################################
# Local variables output
########################################################################################

output "existing_service_accounts" {
  description = "List of existing service accounts"
  value = [
    for sa_name, exists in {
      "project-sa"      = local.project_sa_exists
      "cloudbuild-sa"   = local.cloud_build_sa_exists
      "clouddeploy-sa"  = local.cloud_deploy_sa_exists
      "gke-sa"          = local.gke_sa_exists
      "cloudrun-sa"     = local.cloud_run_sa_exists
      "cloudsql-sa"     = local.cloud_sql_sa_exists
      "nfsserver-sa"    = local.nfs_server_sa_exists
      "setupserver-sa"  = local.setup_server_sa_exists
    } : sa_name if exists
  ]
}

#########################################################################
# Create Service Account
#########################################################################

resource "google_service_account" "odoo_sa" {
  account_id   = "odoo-sa-${var.tenant_deployment_id}"
  display_name = "Odoo Service Account"
  project      = local.project.project_id
}

resource "google_project_iam_member" "cloudsql_client" {
  project = local.project.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.odoo_sa.email}"
}

resource "google_project_iam_member" "secret_accessor" {
  project = local.project.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.odoo_sa.email}"
}

resource "google_project_iam_member" "storage_admin" {
  project = local.project.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.odoo_sa.email}"
}