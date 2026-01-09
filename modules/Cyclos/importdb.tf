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
# Configurations for backup import
#########################################################################

# Create db import script
resource "local_file" "import_db_script_output" {
  count    = local.sql_server_exists ? 1 : 0  
  filename = "${path.module}/scripts/app/import-db.sh"
  content = templatefile("${path.module}/scripts/app/import_db.tpl", {
    PROJECT_ID          = local.project.project_id
    BACKUP_FILEID       = "${var.application_backup_fileid}"
    DB_IP               = local.db_internal_ip
    DB_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
    DB_USER             = "app${var.application_database_user}${var.tenant_deployment_id}${local.random_id}"
    DB_PASS             = data.google_secret_manager_secret_version.db_password[count.index].secret_data
    PG_PASS             = local.db_root_password
    APP_NAME            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_REGION_1        = length(local.regions) > 0 ? local.regions[0] : ""
    APP_REGION_2        = length(local.regions) > 1 ? local.regions[1] : ""
  })
}

#########################################################################
# Configurations for backup import
#########################################################################

# Resource to import db using Cloud Build (no NFS dependency)
resource "null_resource" "import_db" {
  count    = local.sql_server_exists ? 1 : 0

  # Triggers that cause the resource to be updated/recreated
  triggers = {
    # always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOF
      # Set impersonation flag if service account is provided
      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
      fi

      # Execute the import script via Cloud Build (no NFS required)
      echo "Executing database import script via Cloud Build..."

      # Create temporary Cloud Build config
      cat > ${path.module}/scripts/app/cloudbuild-db-import.yaml <<'CLOUDBUILD'
steps:
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk:slim'
    script: |
      #!/bin/bash
      set -e
      echo "Installing dependencies..."
      apt-get update && apt-get install -y postgresql-client python3-pip unzip
      pip3 install gdown
      echo "Executing database import script..."
      bash ${path.module}/scripts/app/import-db.sh
timeout: 1800s
options:
  logging: CLOUD_LOGGING_ONLY
CLOUDBUILD

      # Submit Cloud Build job
      gcloud builds submit ${path.module}/scripts/app \
        --config=${path.module}/scripts/app/cloudbuild-db-import.yaml \
        --project=${local.project.project_id} \
        $IMPERSONATE_FLAG || exit 1

      # Clean up
      rm -f ${path.module}/scripts/app/cloudbuild-db-import.yaml
    EOF
  }

  depends_on = [
    data.google_secret_manager_secret_version.db_password,
    google_secret_manager_secret.db_password,
    local_file.import_db_script_output,
  ]
}
