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

        # Passing root password as value since we don't have a guaranteed secret for it
        env {
          name  = "ROOT_PASS"
          value = local.db_root_password
        }

        env {
          name = "DB_PASS"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.db_password.secret_id
              version = "latest"
            }
          }
        }

        command = ["/bin/sh", "-c"]
        args = [<<-EOT
          set -e

          echo "================================================"
          echo "Starting DB Import Job"
          echo "================================================"
          echo "DB_HOST: $DB_HOST"
          echo "DB_NAME: $DB_NAME"
          echo "DB_USER: $DB_USER"
          echo "================================================"

          # Install required packages
          echo "Installing packages..."
          apk add --no-cache postgresql-client netcat-openbsd

          # Test network connectivity
          echo "Testing connectivity to $DB_HOST on port 5432..."
          if nc -zv $DB_HOST 5432 2>&1; then
            echo "✓ Port 5432 is reachable"
          else
            echo "✗ Cannot reach $DB_HOST:5432"
            exit 1
          fi

          # Set passwords
          export PGPASSWORD=$ROOT_PASS

          # Test PostgreSQL connection
          echo "Testing PostgreSQL connection..."
          if psql -h $DB_HOST -U postgres -d postgres -c "SELECT version();" > /dev/null 2>&1; then
            echo "✓ PostgreSQL connection successful"
          else
            echo "✗ PostgreSQL connection failed"
            exit 1
          fi

          # Create/Update Role
          echo "Creating/updating database role..."
          psql -h $DB_HOST -U postgres -d postgres <<SQL
          DO \$\$
          BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
              CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';
              RAISE NOTICE 'Role $DB_USER created';
            ELSE
              ALTER ROLE $DB_USER WITH PASSWORD '$DB_PASS';
              RAISE NOTICE 'Role $DB_USER updated';
            END IF;
          END
          \$\$;
          ALTER ROLE $DB_USER CREATEDB;
          GRANT ALL PRIVILEGES ON DATABASE postgres TO $DB_USER;
          GRANT $DB_USER TO postgres;
SQL

          # Create Database if not exists
          echo "Checking if database exists..."
          if ! psql -h $DB_HOST -U postgres -lqt | cut -d \| -f 1 | grep -qw $DB_NAME; then
            echo "Creating database $DB_NAME..."
            psql -h $DB_HOST -U postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
            echo "✓ Database created"

            # Grant privileges on the new database
            psql -h $DB_HOST -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
          else
            echo "✓ Database $DB_NAME already exists"
          fi

          echo "================================================"
          echo "✓ DB Import Job Completed Successfully"
          echo "================================================"
        EOT
        ]
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_name}"
        }
        egress = "PRIVATE_RANGES_ONLY"
      }
    }
  }

  depends_on = [
    data.google_secret_manager_secret_version.db_password,
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
        echo "✓ DB import job completed successfully"
      else
        echo "✗ DB import job failed"
        exit 1
      fi
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.import_db_job,
    google_secret_manager_secret_version.db_password,
  ]
}

# ============================================================================
# NFS Setup Job
# ============================================================================

resource "google_cloud_run_v2_job" "nfs_setup_job" {
  count      = local.nfs_server_exists ? 1 : 0
  project    = local.project.project_id
  name       = "nfs-setup-${var.application_name}${var.tenant_deployment_id}${local.random_id}"
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
          name  = "DB_USER"
          value = "app${var.application_database_user}${var.tenant_deployment_id}${local.random_id}"
        }

        command = ["/bin/sh", "-c"]
        args = [<<-EOT
          set -e
          echo "Starting NFS Setup Job"

          # Create directory
          echo "Creating directory /mnt/nfs/$DB_USER..."
          mkdir -p /mnt/nfs/$DB_USER

          # Set ownership (www-data:www-data is 33:33 in standard linux/alpine)
          # Moodle/Bitnami often runs as 1001. Current script used www-data:www-data.
          # We will stick to 33:33 (www-data) as per original script.
          echo "Setting ownership..."
          chown -R 33:33 /mnt/nfs/$DB_USER

          # Set permissions
          echo "Setting permissions..."
          chmod 775 /mnt/nfs/$DB_USER

          echo "✓ NFS Setup completed"
        EOT
        ]

        volume_mounts {
          name       = "nfs-root"
          mount_path = "/mnt/nfs"
        }
      }

      volumes {
        name = "nfs-root"
        nfs {
          server = local.nfs_internal_ip
          path   = "/share"
        }
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_name}"
        }
        egress = "PRIVATE_RANGES_ONLY"
      }
    }
  }
}

resource "null_resource" "execute_nfs_setup_job" {
  count = local.nfs_server_exists ? 1 : 0

  triggers = {
    job_id = google_cloud_run_v2_job.nfs_setup_job[0].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      echo "Executing NFS setup job..."

      # Set impersonation flag if service account is provided
      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
      fi

      # Execute the Cloud Run job
      gcloud run jobs execute ${google_cloud_run_v2_job.nfs_setup_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        $IMPERSONATE_FLAG \
        --wait

      if [ $? -eq 0 ]; then
        echo "✓ NFS setup job completed successfully"
      else
        echo "✗ NFS setup job failed"
        exit 1
      fi
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.nfs_setup_job
  ]
}
