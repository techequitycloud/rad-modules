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

# ============================================================================
# Import DB Job
# ============================================================================

resource "google_cloud_run_v2_job" "import_db_job" {
  count      = local.sql_server_exists ? 1 : 0
  project    = local.project.project_id
  name       = "import-db-${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  location   = local.region
  deletion_protection = false

  template {
    template {
      service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries     = 0
      timeout         = "600s"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "alpine:3.19"

        env {
          name  = "DB_HOST"
          value = "${local.db_internal_ip}"
        }
        env {
          name  = "DB_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        }
        env {
          name  = "DB_USER"
          value = "app${var.application_database_user}${var.tenant_deployment_id}${local.random_id}"
        }
        env {
          name  = "BACKUP_FILEID"
          value = "${var.application_backup_fileid}"
        }

        env {
          name = "ROOT_PASS"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-root-password"
              version = "latest"
            }
          }
        }

        env {
          name = "DB_PASS"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}-password-${var.tenant_deployment_id}-${local.random_id}"
              version = "latest"
            }
          }
        }

        command = ["/bin/sh"]
        args = ["-c", <<EOF
set -e
apk add --no-cache postgresql-client python3 py3-pip unzip sudo curl
# Install gdown via pip (using --break-system-packages as per Alpine 3.19+ policy or use venv)
pip3 install gdown --break-system-packages

export PGPASSWORD=$$ROOT_PASS
export DB_PASS=$$DB_PASS

echo "Checking connectivity to $$DB_HOST..."
# Create/Update Role
psql -h $$DB_HOST -U postgres -d postgres <<SQL
DO \$$\$$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$$DB_USER') THEN
    CREATE ROLE $$DB_USER WITH LOGIN PASSWORD '$$DB_PASS';
  ELSE
    ALTER ROLE $$DB_USER WITH PASSWORD '$$DB_PASS';
  END IF;
END
\$$\$$;
ALTER ROLE $$DB_USER CREATEDB;
GRANT ALL PRIVILEGES ON DATABASE postgres TO $$DB_USER;
SQL

# Create Database if not exists
if ! psql -h $$DB_HOST -U postgres -lqt | cut -d \| -f 1 | grep -qw $$DB_NAME; then
  echo "Creating database $$DB_NAME..."
  psql -h $$DB_HOST -U postgres -c "CREATE DATABASE $$DB_NAME OWNER $$DB_USER;"
else
  echo "Database $$DB_NAME already exists."
fi

# Extensions
psql -h $$DB_HOST -U postgres -d $$DB_NAME <<SQL
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS unaccent;
SQL

# Download and Restore Backup if provided
if [ -n "$$BACKUP_FILEID" ]; then
  echo "Downloading backup..."
  gdown $$BACKUP_FILEID -O $${DB_NAME}.zip
  
  if [ -f "$${DB_NAME}.zip" ]; then
    echo "Restoring backup..."
    unzip $${DB_NAME}.zip -d restore_dir
    export PGPASSWORD=$$DB_PASS
    # Find dump.sql inside restore_dir (it might be in a subdir)
    DUMP_FILE=$$(find restore_dir -name "dump.sql" | head -n 1)
    
    if [ -n "$$DUMP_FILE" ]; then
        psql -h $$DB_HOST -U $$DB_USER -d $$DB_NAME < "$$DUMP_FILE"
        echo "Restore complete."
    else
        echo "dump.sql not found in zip archive."
        exit 1
    fi
  fi
fi
EOF
        ]
      }

      vpc_access {
        network_interfaces {
          network = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
        }
      }
    }
  }
  
  depends_on = [
    data.google_secret_manager_secret_version.db_password,
    # google_project_iam_member.secret_accessor, # Assumed to be handled in iam.tf or broadly
    # google_project_iam_member.cloudsql_client
  ]
}

resource "null_resource" "execute_import_db_job" {
  count = local.sql_server_exists ? 1 : 0

  triggers = {
    job_id = google_cloud_run_v2_job.import_db_job[0].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      echo "Executing DB import job..."
      gcloud run jobs execute ${google_cloud_run_v2_job.import_db_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        --wait

      if [ $? -eq 0 ]; then
        echo "✓ DB import/init job completed successfully"
      else
        echo "✗ DB import/init job failed"
        exit 1
      fi
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.import_db_job,
    google_secret_manager_secret_version.db_password
  ]
}
