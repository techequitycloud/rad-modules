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
    CLOUD_BUILD_SA_EXISTS=$(check_sa "cloudbuild-sa")
    CLOUD_RUN_SA_EXISTS=$(check_sa "cloudrun-sa")

    # Output JSON
    cat <<EOF
{
  "cloud_build_sa_exists": "$CLOUD_BUILD_SA_EXISTS",
  "cloud_run_sa_exists": "$CLOUD_RUN_SA_EXISTS"
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
  cloud_build_sa_exists  = data.external.check_service_accounts.result["cloud_build_sa_exists"] == "true"
  cloud_run_sa_exists    = data.external.check_service_accounts.result["cloud_run_sa_exists"] == "true"

  # Service account references (existing or newly created)
  cloud_build_sa_email  = "cloudbuild-sa@${local.project.project_id}.iam.gserviceaccount.com"
  cloud_run_sa_email    = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
}
