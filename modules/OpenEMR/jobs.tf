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
  count      = local.sql_server_exists == "true" ? 1 : 0
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

        resources {
          limits = {
            cpu    = "2"
            memory = "4Gi"
          }
        }

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

        command = ["/bin/sh", "-c"]
        args = [<<-EOT
          set -e

          echo "================================================"
          echo "Starting DB Import Job"
          echo "================================================"
          echo "DB_HOST: $DB_HOST"
          echo "DB_NAME: $DB_NAME"
          echo "DB_USER: $DB_USER"
          echo "BACKUP_FILEID: $BACKUP_FILEID"
          echo "================================================"

          # Install required packages
          echo "Installing packages..."
          apk add --no-cache mariadb-client python3 py3-pip unzip curl netcat-openbsd

          # Install gdown
          echo "Installing gdown..."
          pip3 install gdown --break-system-packages

          # Test network connectivity
          echo "Testing connectivity to $DB_HOST on port 3306..."
          if nc -zv $DB_HOST 3306 2>&1; then
            echo "✓ Port 3306 is reachable"
          else
            echo "✗ Cannot reach $DB_HOST:3306"
            exit 1
          fi

          # Create .my.cnf for root
          cat > /root/.my.cnf <<EOF
[client]
user=root
password=$ROOT_PASS
host=$DB_HOST
EOF
          chmod 600 /root/.my.cnf

          # Test MySQL connection
          echo "Testing MySQL connection..."
          if mysql -e "SELECT version();" > /dev/null 2>&1; then
            echo "✓ MySQL connection successful"
          else
            echo "✗ MySQL connection failed"
            mysql -e "SELECT version();" || true
            exit 1
          fi

          # Create User
          echo "Creating/updating user $DB_USER..."
          mysql <<EOF
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
FLUSH PRIVILEGES;
EOF

          # Create Database if not exists
          echo "Checking if database exists..."
          if ! mysql -e "SHOW DATABASES LIKE '$DB_NAME'" | grep "$DB_NAME"; then
            echo "Creating database $DB_NAME..."
            mysql -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
            echo "✓ Database created"
          else
            echo "✓ Database $DB_NAME already exists"
          fi

          # Grant Privileges
          echo "Granting privileges..."
          mysql <<EOF
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
GRANT GRANT OPTION ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

          # Download and Restore Backup if provided
          if [ -n "$BACKUP_FILEID" ]; then
            echo "Downloading backup from Google Drive..."
            echo "File ID: $BACKUP_FILEID"

            BACKUP_FILE="$DB_NAME.zip"
            if gdown $BACKUP_FILEID -O "$BACKUP_FILE"; then
              echo "✓ Backup downloaded"

              if [ -f "$BACKUP_FILE" ]; then
                echo "Extracting backup..."
                unzip -q "$BACKUP_FILE" -d restore_dir
                echo "✓ Backup extracted"

                # Create user-specific .my.cnf
                cat > /root/.my.cnf.user <<EOF
[client]
user=$DB_USER
password=$DB_PASS
host=$DB_HOST
EOF
                chmod 600 /root/.my.cnf.user

                # Find dump.sql
                DUMP_FILE=$(find restore_dir -name "dump.sql" | head -n 1)

                if [ -n "$DUMP_FILE" ]; then
                  echo "Restoring database from $DUMP_FILE..."
                  if mysql --defaults-file=/root/.my.cnf.user "$DB_NAME" < "$DUMP_FILE"; then
                    echo "✓ Database restore complete"
                  else
                    echo "✗ Database restore failed"
                    exit 1
                  fi
                else
                  echo "✗ dump.sql not found in zip archive"
                  echo "Contents of restore_dir:"
                  find restore_dir -type f
                  exit 1
                fi
              else
                echo "✗ Zip file not found after download"
                exit 1
              fi
            else
              echo "✗ Failed to download backup"
              exit 1
            fi
          else
            echo "ℹ No backup file specified, skipping restore"
          fi

          # Cleanup
          rm -f /root/.my.cnf /root/.my.cnf.user

          echo "================================================"
          echo "✓ DB Import Job Completed Successfully"
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
    data.google_secret_manager_secret_version.db_password,
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

        resources {
          limits = {
            cpu    = "2"
            memory = "4Gi"
          }
        }

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

        volume_mounts {
          name       = "nfs-root"
          mount_path = "/mnt/nfs"
        }

        command = ["/bin/sh", "-c"]
        args = [<<-EOT
          set -e

          echo "================================================"
          echo "Starting NFS Setup Job"
          echo "================================================"

          APP_DIR="/mnt/nfs/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"

          # Install packages
          echo "Installing packages..."
          apk add --no-cache bash python3 py3-pip unzip curl sed

          # Install gdown
          echo "Installing gdown..."
          pip3 install gdown --break-system-packages

          echo "Checking/Creating App Directory: $APP_DIR"
          if [ ! -d "$APP_DIR" ]; then
            echo "Creating directory..."
            mkdir -p "$APP_DIR"
            echo "✓ Directory created"
          else
            echo "✓ Directory already exists"
          fi

          # Set ownership (OpenEMR runs as 1000)
          # Note: NFS mount must allow this.
          echo "Setting ownership..."
          chown 1000:1000 "$APP_DIR"
          chmod 775 "$APP_DIR"

          # Download and Restore Backup if provided
          if [ -n "$BACKUP_FILEID" ]; then
            echo "Downloading backup..."
            BACKUP_FILE="$DB_NAME.zip"

            if gdown $BACKUP_FILEID -O "$BACKUP_FILE"; then
              echo "✓ Backup downloaded"

              if [ -f "$BACKUP_FILE" ]; then
                echo "Extracting backup to $APP_DIR..."
                # Clean target dir (except if it was just created)
                rm -rf "$APP_DIR"/*

                # Unzip
                unzip -q "$BACKUP_FILE" -d temp_restore

                # Move contents (assuming zip contains the folder structure or just files)

                if [ -d "temp_restore/$DB_NAME" ]; then
                  mv temp_restore/$DB_NAME/* "$APP_DIR"/
                else
                   # Just move whatever is in temp_restore
                   mv temp_restore/* "$APP_DIR"/
                fi

                echo "✓ Files restored"

                # Update sqlconf.php
                SQLCONF_FILE="$APP_DIR/default/sqlconf.php"
                if [ -f "$SQLCONF_FILE" ]; then
                  echo "Updating $SQLCONF_FILE..."
                  sed -i "s/\$host\s*=\s*'[^']*'/\$host = '$DB_HOST'/" "$SQLCONF_FILE"
                  sed -i "s/\$port\s*=\s*'[^']*'/\$port = '3306'/" "$SQLCONF_FILE"
                  sed -i "s/\$login\s*=\s*'[^']*'/\$login = '$DB_USER'/" "$SQLCONF_FILE"
                  sed -i "s/\$pass\s*=\s*'[^']*'/\$pass = '$DB_PASS'/" "$SQLCONF_FILE"
                  sed -i "s/\$dbase\s*=\s*'[^']*'/\$dbase = '$DB_NAME'/" "$SQLCONF_FILE"
                  # Add rootpass if needed (though it's usually not in sqlconf for security)
                  # The original script added it.
                  if ! grep -q "\$rootpass" "$SQLCONF_FILE"; then
                     sed -i "/\$pass\s*=\s*'[^']*'/a \$rootpass = '$ROOT_PASS';" "$SQLCONF_FILE"
                  else
                     sed -i "s/\$rootpass\s*=\s*'[^']*'/\$rootpass = '$ROOT_PASS'/" "$SQLCONF_FILE"
                  fi

                  echo "✓ Config updated"
                else
                  echo "⚠ sqlconf.php not found at $SQLCONF_FILE"
                fi

                # Permissions update
                echo "Updating permissions..."
                chown -R 1000:1000 "$APP_DIR"
                find "$APP_DIR" -type d -exec chmod 755 {} \;
                find "$APP_DIR" -type f -exec chmod 644 {} \;
                if [ -d "$APP_DIR/default/documents" ]; then
                  chmod -R 755 "$APP_DIR/default/documents"
                fi
                if [ -f "$SQLCONF_FILE" ]; then
                  chmod 600 "$SQLCONF_FILE"
                fi

              else
                 echo "✗ Zip file not found"
                 exit 1
              fi
            else
               echo "✗ Download failed"
               exit 1
            fi
          else
             echo "ℹ No backup specified"
          fi

          echo "================================================"
          echo "✓ NFS Setup Job Completed Successfully"
          echo "================================================"
        EOT
        ]
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
          tags = ["nfsserver"]
        }
        egress = "PRIVATE_RANGES_ONLY"
      }

      volumes {
        name = "nfs-root"
        nfs {
          server = "${local.nfs_internal_ip}"
          path   = "/share"
        }
      }
    }
  }
}

resource "null_resource" "execute_import_db_job" {
  count = local.sql_server_exists == "true" ? 1 : 0

  triggers = {
    job_id = google_cloud_run_v2_job.import_db_job[0].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      echo "Executing DB import job..."

      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
        echo "Using impersonation: ${local.impersonation_service_account}"
      fi

      echo "Waiting for IAM permissions to propagate..."
      sleep 15

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
        exit 1
      fi
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.import_db_job,
    google_secret_manager_secret_version.db_password,
  ]
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

      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
        echo "Using impersonation: ${local.impersonation_service_account}"
      fi

      echo "Waiting for IAM permissions to propagate..."
      sleep 15

      echo "Starting job execution..."
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
    google_cloud_run_v2_job.nfs_setup_job,
    google_secret_manager_secret_version.db_password,
  ]
}
