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
    if [ -n "${local.impersonation_service_account}" ]; then
      SA_ARG="--impersonate-service-account=${local.impersonation_service_account}"
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

    # Check only service accounts used in Cloud Run deployment
    PROJECT_SA_EXISTS=$(check_sa "${local.project.project_id}")
    CLOUD_BUILD_SA_EXISTS=$(check_sa "cloudbuild-sa")
    CLOUD_RUN_SA_EXISTS=$(check_sa "cloudrun-sa")
    CLOUD_SQL_SA_EXISTS=$(check_sa "cloudsql-sa")

    # Output JSON
    cat <<EOF
{
  "project_sa_exists": "$PROJECT_SA_EXISTS",
  "cloud_build_sa_exists": "$CLOUD_BUILD_SA_EXISTS",
  "cloud_run_sa_exists": "$CLOUD_RUN_SA_EXISTS",
  "cloud_sql_sa_exists": "$CLOUD_SQL_SA_EXISTS"
}
EOF
  EOT
  ]
}

########################################################################################
# Local variables to check service account existence
########################################################################################

locals {

  # Parse the results from external data source (only Cloud Run deployment SAs)
  project_sa_exists      = data.external.check_service_accounts.result["project_sa_exists"] == "true"
  cloud_build_sa_exists  = data.external.check_service_accounts.result["cloud_build_sa_exists"] == "true"
  cloud_run_sa_exists    = data.external.check_service_accounts.result["cloud_run_sa_exists"] == "true"
  cloud_sql_sa_exists    = data.external.check_service_accounts.result["cloud_sql_sa_exists"] == "true"

  # Service account references (existing or newly created)
  project_sa_email      = "project-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloud_build_sa_email  = "cloudbuild-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloud_run_sa_email    = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloud_sql_sa_email    = "cloudsql-sa@${local.project.project_id}.iam.gserviceaccount.com"

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
      "cloudrun-sa"     = local.cloud_run_sa_exists
      "cloudsql-sa"     = local.cloud_sql_sa_exists
    } : sa_name if exists
  ]
}

########################################################################################
# Cloud Run Service Account IAM Bindings
########################################################################################

resource "google_project_iam_member" "cloudsql_client" {
  project = local.project.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${local.cloud_run_sa_email}"
}

resource "google_project_iam_member" "secret_accessor" {
  project = local.project.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${local.cloud_run_sa_email}"
}

########################################################################################
# HMAC Key for Cloud Run Service Account (used by n8n)
########################################################################################

resource "google_storage_hmac_key" "n8n_key" {
  service_account_email = local.cloud_run_sa_email
  project               = local.project.project_id
}

########################################################################################
# Project Service Account Token Creator Role
########################################################################################

resource "google_service_account_iam_binding" "resource_creator_identity_token_creator_role" {
  count = var.resource_creator_identity != null && var.resource_creator_identity != "" ? 1 : 0

  service_account_id = local.project_sa_id
  role               = "roles/iam.serviceAccountTokenCreator"

  members = [
    "serviceAccount:${var.resource_creator_identity}"
  ]
}
