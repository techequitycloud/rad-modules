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
# Pre-create NFS directories using Cloud Run Job (no SSH required)
# ============================================================================
resource "google_cloud_run_v2_job" "prepare_nfs_directories" {
  count    = local.nfs_server_exists ? 1 : 0
  project  = local.project.project_id
  name     = "prep-nfs-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  location = local.region
  deletion_protection = false

  template {
    template {
      service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries     = 0
      timeout         = "300s"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
      
      containers {
        image = "alpine:3.19"

        command = ["/bin/sh"]
        args = ["-c", <<-EOT
          set -e
          
          echo "=== Preparing NFS Directories ==="
          echo "Creating directory structure for dev environment..."
          
          # Create all required directories
          mkdir -p /mnt/dev
          
          # Set permissions
          chmod 777 /mnt/dev
          
          echo "✓ Directories created successfully:"
          ls -la /mnt/
          
          echo "✓ NFS directory preparation complete"
        EOT
        ]
        
        volume_mounts {
          name       = "nfs-dev"
          mount_path = "/mnt/dev"
        }
      }
      
      vpc_access {
        network_interfaces {
          network = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
          tags = ["nfsserver"]
        }
      }

      volumes {
        name = "nfs-dev"
        nfs {
          server = local.nfs_internal_ip
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
        }
      }
    }
  }
  
  depends_on = [
    data.external.nfs_instance_info,
    null_resource.create_nfs_directories_on_server
  ]
}

resource "null_resource" "execute_prepare_nfs" {
  count = local.nfs_server_exists ? 1 : 0

  triggers = {
    job_id = google_cloud_run_v2_job.prepare_nfs_directories[0].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      echo "Executing NFS preparation job..."
      gcloud run jobs execute ${google_cloud_run_v2_job.prepare_nfs_directories[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        --wait
      
      if [ $? -eq 0 ]; then
        echo "✓ NFS directories prepared successfully"
      else
        echo "✗ NFS directory preparation failed"
        exit 1
      fi
    EOT
  }
  
  depends_on = [
    google_cloud_run_v2_job.prepare_nfs_directories
  ]
}

# ============================================================================
# Backup Services
# ============================================================================

resource "google_cloud_run_v2_job" "dev_backup_service" {
  count      = var.configure_backups && var.configure_development_environment ? 1 : 0
  project    = local.project.project_id  
  name       = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
  location   = local.region
  deletion_protection = false

  template {
    parallelism = 1
    task_count  = 1

    labels = {
      app : var.application_name,
      env : "dev"
    }

    template {
      service_account       = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries           = 3
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/backup:${var.application_version}"

        env {
          name  = "DB_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
        }

        env {
          name  = "DB_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}dev-password-${var.tenant_deployment_id}-${local.random_id}"
              version = "latest"
            }
          }
        }

        env {
          name  = "DB_HOST"
          value = "${local.db_internal_ip}"
        }

        volume_mounts {
          name      = "gcs-backup-volume"
          mount_path = "/data"
        }

        volume_mounts {
          name      = "nfs-data-volume"
          mount_path = "/mnt"
        }
      }

      vpc_access {
        network_interfaces {
          network = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
          tags = ["nfsserver"]
        }
      }

      volumes {
        name = "gcs-backup-volume"
        gcs {
          bucket = "${local.backup_bucket_name}"
        }
      }

      volumes {
        name = "nfs-data-volume"
        nfs {
          server = "${local.nfs_internal_ip}"
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
        }
      }
    }
  }

  depends_on = [
    null_resource.import_dev_db,
    null_resource.import_dev_nfs,
    null_resource.build_and_push_backup_image,
  ]
}


# ============================================================================
# Initialization Jobs
# ============================================================================

# Development Initialization Job
resource "google_cloud_run_v2_job" "dev_init_job" {
  count      = var.configure_development_environment && local.nfs_server_exists ? 1 : 0
  project    = local.project.project_id
  name       = "init${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
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
          name  = "MYSQL_DATABASE"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
        }

        env {
          name  = "MYSQL_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
        }

        env {
          name = "MYSQL_PASS"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}dev-password-${var.tenant_deployment_id}-${local.random_id}"
              version = "latest"
            }
          }
        }

        env {
          name  = "MYSQL_HOST"
          value = "${local.db_internal_ip}"
        }

        env {
          name = "MYSQL_ROOT_PASS"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-root-password"
              version = "latest"
            }
          }
        }

        env {
          name  = "MYSQL_PORT"
          value = "3306"
        }
        
        volume_mounts {
          name       = "nfs-data-volume"
          mount_path = "/mnt/sites"
        }

        command = ["/bin/sh"]
        args = [
          "-c",
          <<-EOT
          set -e
          
          echo "=== NFS Initialization Script (DEV) ==="
          echo "Environment Check:"
          echo "  MYSQL_HOST: $$MYSQL_HOST"
          echo "  MYSQL_DATABASE: $$MYSQL_DATABASE"
          echo "  MYSQL_USER: $$MYSQL_USER"
          echo "  MYSQL_PORT: $$MYSQL_PORT"
          
          echo "Checking /mnt/sites..."
          
          # Verify NFS mount is accessible
          if ! ls /mnt/sites > /dev/null 2>&1; then
            echo "ERROR: Cannot access /mnt/sites - NFS mount may have failed"
            exit 1
          fi
          
          # Check if already initialized
          if [ -f /mnt/sites/default/sqlconf.php ]; then
            echo "✓ /mnt/sites/default/sqlconf.php exists. Skipping initialization."
            exit 0
          fi
          
          echo "Initializing NFS share..."
          
          # Create directory structure
          mkdir -p /mnt/sites/default
          
          # Install required packages
          echo "Installing required packages..."
          apk add --no-cache wget php81
          
          # Create sqlconf.php using printf to avoid escaping issues
          echo "Creating sqlconf.php configuration file..."
          printf '%s\n' \
            '<?php' \
            '//  OpenEMR' \
            '//  MySQL Config' \
            '' \
            '$host = '"'"'DBHOST_PLACEHOLDER'"'"';' \
            '$port = '"'"'3306'"'"';' \
            '$login = '"'"'DBUSER_PLACEHOLDER'"'"';' \
            '$pass = '"'"'DBPASS_PLACEHOLDER'"'"';' \
            '$dbase = '"'"'DBNAME_PLACEHOLDER'"'"';' \
            '$rootpass = '"'"'ROOTPASS_PLACEHOLDER'"'"';' \
            '$db_encoding = '"'"'utf8mb4'"'"';' \
            '' \
            '$sqlconf = [];' \
            'global $sqlconf;' \
            '$sqlconf["host"]= $host;' \
            '$sqlconf["port"] = $port;' \
            '$sqlconf["login"] = $login;' \
            '$sqlconf["pass"] = $pass;' \
            '$sqlconf["dbase"] = $dbase;' \
            '$sqlconf["db_encoding"] = $db_encoding;' \
            '' \
            '//////////////////////////' \
            '//////////////////////////' \
            '//////////////////////////' \
            '//////DO NOT TOUCH THIS///' \
            '$config = 0; /////////////' \
            '//////////////////////////' \
            '//////////////////////////' \
            '//////////////////////////' \
            '?>' \
            > /mnt/sites/default/sqlconf.php
          
          # Replace placeholders with actual values
          echo "Configuring database connection..."
          sed -i "s|DBHOST_PLACEHOLDER|$${MYSQL_HOST}|g" /mnt/sites/default/sqlconf.php
          sed -i "s|DBUSER_PLACEHOLDER|$${MYSQL_USER}|g" /mnt/sites/default/sqlconf.php
          sed -i "s|DBPASS_PLACEHOLDER|$${MYSQL_PASS}|g" /mnt/sites/default/sqlconf.php
          sed -i "s|DBNAME_PLACEHOLDER|$${MYSQL_DATABASE}|g" /mnt/sites/default/sqlconf.php
          sed -i "s|ROOTPASS_PLACEHOLDER|$${MYSQL_ROOT_PASS}|g" /mnt/sites/default/sqlconf.php
          
          # Set permissions
          chmod 755 /mnt/sites/default/sqlconf.php || true
          chmod 755 /mnt/sites/default || true
          chmod 755 /mnt/sites || true
          
          echo "✓ Configuration complete"
          
          # Verify the file was created and validate PHP syntax
          if [ -f /mnt/sites/default/sqlconf.php ]; then
            echo "✓ File created successfully"
            
            # Show file contents for debugging
            echo "=== File contents ==="
            cat /mnt/sites/default/sqlconf.php
            
            # Validate PHP syntax
            echo "Validating PHP syntax..."
            if php -l /mnt/sites/default/sqlconf.php; then
              echo "✓ PHP syntax validation passed"
              echo "✓ Initialization successful"
              exit 0
            else
              echo "ERROR: PHP syntax validation failed"
              exit 1
            fi
          else
            echo "ERROR: sqlconf.php was not created"
            exit 1
          fi
          EOT
        ]
      }
      
      vpc_access {
        network_interfaces {
          network = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
          tags = ["nfsserver"]
        }
      }

      volumes {
        name = "nfs-data-volume"
        nfs {
          server = "${local.nfs_internal_ip}"
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
        }
      }
    }
  }
  
  depends_on = [
    null_resource.import_dev_nfs,
    null_resource.execute_prepare_nfs
  ]
}

resource "null_resource" "execute_dev_init_job" {
  count = var.configure_development_environment && local.nfs_server_exists ? 1 : 0

  triggers = {
    job_id = google_cloud_run_v2_job.dev_init_job[0].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      gcloud run jobs execute ${google_cloud_run_v2_job.dev_init_job[0].name} --region ${local.region} --project ${local.project.project_id} --wait
    EOT
  }
  
  depends_on = [
    google_cloud_run_v2_job.dev_init_job
  ]
}

