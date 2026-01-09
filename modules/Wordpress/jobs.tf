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

        command = ["/bin/sh", "-c"]
        args = [<<-EOT
          set -e

          echo "================================================"
          echo "Starting DB Import/Init Job"
          echo "================================================"
          echo "DB_HOST: $DB_HOST"
          echo "DB_NAME: $DB_NAME"
          echo "DB_USER: $DB_USER"
          echo "================================================"

          # Install required packages
          echo "Installing packages..."
          apk add --no-cache mysql-client netcat-openbsd

          # Test network connectivity
          echo "Testing connectivity to $DB_HOST on port 3306..."
          if nc -zv $DB_HOST 3306 2>&1; then
            echo "✓ Port 3306 is reachable"
          else
            echo "✗ Cannot reach $DB_HOST:3306"
            exit 1
          fi

          # Create MySQL configuration file
          echo "Configuring MySQL client..."
          rm -rf ~/.my.cnf
          cat > ~/.my.cnf << EOF
[client]
user=root
password=$ROOT_PASS
host=$DB_HOST
EOF
          chmod 600 ~/.my.cnf

          # Verify connection
          echo "Verifying MySQL connection..."
          if mysql --defaults-file=~/.my.cnf -e "SELECT VERSION();" > /dev/null 2>&1; then
             echo "✓ MySQL connection successful"
          else
             echo "✗ MySQL connection failed"
             exit 1
          fi

          # Create User if not exists
          echo "Checking/Creating user $DB_USER..."
          mysql --defaults-file=~/.my.cnf <<EOF
CREATE USER IF NOT EXISTS '$${DB_USER}'@'%' IDENTIFIED BY '$${DB_PASS}';
ALTER USER '$${DB_USER}'@'%' IDENTIFIED BY '$${DB_PASS}';
FLUSH PRIVILEGES;
EOF
          echo "✓ User processed"

          # Create Database if not exists
          echo "Checking/Creating database $DB_NAME..."
          mysql --defaults-file=~/.my.cnf -e "CREATE DATABASE IF NOT EXISTS \`$${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
          echo "✓ Database processed"

          # Grant Privileges
          echo "Granting privileges..."
          mysql --defaults-file=~/.my.cnf <<EOF
GRANT ALL PRIVILEGES ON \`$${DB_NAME}\`.* TO '$${DB_USER}'@'%';
GRANT GRANT OPTION ON \`$${DB_NAME}\`.* TO '$${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF
          echo "✓ Privileges granted"

          # Clean up
          rm -f ~/.my.cnf

          echo "================================================"
          echo "✓ DB Init Job Completed Successfully"
          echo "================================================"
        EOT
        ]
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
        }
        egress = "PRIVATE_RANGES_ONLY"
      }
    }
  }

  depends_on = [
    data.google_secret_manager_secret_version.db_password_data,
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

      # Set impersonation flag if service account is provided
      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
        echo "Using impersonation: ${local.impersonation_service_account}"
      fi

      # Wait for IAM permissions to propagate
      echo "Waiting for IAM permissions to propagate..."
      sleep 15

      # Execute the Cloud Run job
      echo "Starting job execution..."
      gcloud run jobs execute ${google_cloud_run_v2_job.import_db_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        $IMPERSONATE_FLAG \
        --wait

      if [ $? -eq 0 ]; then
        echo "✓ DB import/init job completed successfully"
      else
        echo "✗ DB import/init job failed"
        echo "Check logs at: https://console.cloud.google.com/run/jobs/details/${local.region}/${google_cloud_run_v2_job.import_db_job[0].name}?project=${local.project.project_id}"
        exit 1
      fi
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.import_db_job,
    google_secret_manager_secret_version.db_password,
  ]
}
