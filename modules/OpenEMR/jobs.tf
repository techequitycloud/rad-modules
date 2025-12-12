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

# Pre-create NFS directories to ensure they exist before init jobs run
resource "null_resource" "prepare_nfs_directories" {
  count = local.nfs_server_exists ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      gcloud compute ssh ${local.nfs_instance_name} \
        --zone=${local.nfs_instance_zone} \
        --project=${local.project.project_id} \
        --command="
          sudo mkdir -p /share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev \
                       /share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa \
                       /share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod && \
          sudo chmod 777 /share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}* && \
          sudo exportfs -ra
        "
    EOT
  }

  depends_on = [
    data.external.nfs_instance_info
  ]
}

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

resource "google_cloud_run_v2_job" "qa_backup_service" {
  count      = var.configure_backups && var.configure_nonproduction_environment ? 1 : 0
  project    = local.project.project_id  
  name       = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
  location   = local.region
  deletion_protection = false

  template {
    parallelism = 1
    task_count  = 1

    labels = {
      app : var.application_name,
      env : "qa"
    }

    template {
      service_account       = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries           = 3
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/backup:${var.application_version}"

        env {
          name  = "DB_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
        }

        env {
          name  = "DB_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}qa-password-${var.tenant_deployment_id}-${local.random_id}"
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
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
        }
      }
    }
  }

  depends_on = [
    null_resource.import_qa_db,
    null_resource.import_qa_nfs,
    google_cloud_run_v2_job.dev_backup_service,
    null_resource.build_and_push_backup_image,
  ]
}

resource "google_cloud_run_v2_job" "prod_backup_service" {
  count      = var.configure_backups && var.configure_production_environment ? 1 : 0
  project    = local.project.project_id  
  name       = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
  location   = local.region
  deletion_protection = false

  template {
    parallelism = 1
    task_count  = 1

    labels = {
      app : var.application_name
      env : "prod"
    }

    template {
      service_account       = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries           = 3
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/backup:${var.application_version}"

        env {
          name  = "DB_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
        }

        env {
          name  = "DB_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}prod-password-${var.tenant_deployment_id}-${local.random_id}"
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
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
        }
      }
    }
  }

  depends_on = [
    null_resource.import_prod_db,
    null_resource.import_prod_nfs,
    google_cloud_run_v2_job.qa_backup_service,
    null_resource.build_and_push_backup_image,
  ]
}

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
        args = ["-c", <<-EOT
          set -e
          
          echo "=== NFS Initialization Script (DEV) ==="
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
          
          # Download OpenEMR sqlconf.php template
          echo "Downloading sqlconf.php template..."
          apk add --no-cache wget
          wget -O /mnt/sites/default/sqlconf.php \
            https://raw.githubusercontent.com/openemr/openemr/master/sites/default/sqlconf.php || {
            echo "ERROR: Failed to download sqlconf.php template"
            exit 1
          }
          
          # Configure database connection
          echo "Configuring database connection..."
          SQLCONF="/mnt/sites/default/sqlconf.php"
          
          # Update database configuration
          sed -i "s/\\\$host = 'localhost'/\\\$host = '${local.db_internal_ip}'/" "$SQLCONF"
          sed -i "s/\\\$port = '3306'/\\\$port = '3306'/" "$SQLCONF"
          sed -i "s/\\\$login = 'openemr'/\\\$login = '$MYSQL_USER'/" "$SQLCONF"
          sed -i "s/\\\$pass = ''/\\\$pass = '$MYSQL_PASS'/" "$SQLCONF"
          sed -i "s/\\\$dbase = 'openemr'/\\\$dbase = '$MYSQL_DATABASE'/" "$SQLCONF"
          
          # Add root password if not present
          if ! grep -q "\\\$rootpass" "$SQLCONF"; then
            echo "\\\$rootpass = '$MYSQL_ROOT_PASS';" >> "$SQLCONF"
          fi
          
          # Set permissions (NFS may not support chown, so we try but don't fail)
          chmod -R 755 /mnt/sites || true
          
          echo "✓ Configuration complete"
          echo "Created: $SQLCONF"
          
          # Verify the file was created
          if [ -f "$SQLCONF" ]; then
            echo "✓ Initialization successful"
            exit 0
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
    null_resource.prepare_nfs_directories
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

# QA Initialization Job
resource "google_cloud_run_v2_job" "qa_init_job" {
  count      = var.configure_nonproduction_environment && local.nfs_server_exists ? 1 : 0
  project    = local.project.project_id
  name       = "init${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
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
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
        }

        env {
          name  = "MYSQL_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
        }

        env {
          name = "MYSQL_PASS"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}qa-password-${var.tenant_deployment_id}-${local.random_id}"
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
        args = ["-c", <<-EOT
          set -e
          
          echo "=== NFS Initialization Script (QA) ==="
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
          
          # Download OpenEMR sqlconf.php template
          echo "Downloading sqlconf.php template..."
          apk add --no-cache wget
          wget -O /mnt/sites/default/sqlconf.php \
            https://raw.githubusercontent.com/openemr/openemr/master/sites/default/sqlconf.php || {
            echo "ERROR: Failed to download sqlconf.php template"
            exit 1
          }
          
          # Configure database connection
          echo "Configuring database connection..."
          SQLCONF="/mnt/sites/default/sqlconf.php"
          
          # Update database configuration
          sed -i "s/\\\$host = 'localhost'/\\\$host = '${local.db_internal_ip}'/" "$SQLCONF"
          sed -i "s/\\\$port = '3306'/\\\$port = '3306'/" "$SQLCONF"
          sed -i "s/\\\$login = 'openemr'/\\\$login = '$MYSQL_USER'/" "$SQLCONF"
          sed -i "s/\\\$pass = ''/\\\$pass = '$MYSQL_PASS'/" "$SQLCONF"
          sed -i "s/\\\$dbase = 'openemr'/\\\$dbase = '$MYSQL_DATABASE'/" "$SQLCONF"
          
          # Add root password if not present
          if ! grep -q "\\\$rootpass" "$SQLCONF"; then
            echo "\\\$rootpass = '$MYSQL_ROOT_PASS';" >> "$SQLCONF"
          fi
          
          # Set permissions (NFS may not support chown, so we try but don't fail)
          chmod -R 755 /mnt/sites || true
          
          echo "✓ Configuration complete"
          echo "Created: $SQLCONF"
          
          # Verify the file was created
          if [ -f "$SQLCONF" ]; then
            echo "✓ Initialization successful"
            exit 0
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
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
        }
      }
    }
  }
  
  depends_on = [
    null_resource.import_qa_nfs,
    null_resource.prepare_nfs_directories
  ]
}

resource "null_resource" "execute_qa_init_job" {
  count = var.configure_nonproduction_environment && local.nfs_server_exists ? 1 : 0

  triggers = {
    job_id = google_cloud_run_v2_job.qa_init_job[0].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      gcloud run jobs execute ${google_cloud_run_v2_job.qa_init_job[0].name} --region ${local.region} --project ${local.project.project_id} --wait
    EOT
  }
  
  depends_on = [
    google_cloud_run_v2_job.qa_init_job
  ]
}

# Production Initialization Job
resource "google_cloud_run_v2_job" "prod_init_job" {
  count      = var.configure_production_environment && local.nfs_server_exists ? 1 : 0
  project    = local.project.project_id
  name       = "init${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
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
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
        }

        env {
          name  = "MYSQL_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
        }

        env {
          name = "MYSQL_PASS"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}prod-password-${var.tenant_deployment_id}-${local.random_id}"
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
        args = ["-c", <<-EOT
          set -e
          
          echo "=== NFS Initialization Script (PROD) ==="
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
          
          # Download OpenEMR sqlconf.php template
          echo "Downloading sqlconf.php template..."
          apk add --no-cache wget
          wget -O /mnt/sites/default/sqlconf.php \
            https://raw.githubusercontent.com/openemr/openemr/master/sites/default/sqlconf.php || {
            echo "ERROR: Failed to download sqlconf.php template"
            exit 1
          }
          
          # Configure database connection
          echo "Configuring database connection..."
          SQLCONF="/mnt/sites/default/sqlconf.php"
          
          # Update database configuration
          sed -i "s/\\\$host = 'localhost'/\\\$host = '${local.db_internal_ip}'/" "$SQLCONF"
          sed -i "s/\\\$port = '3306'/\\\$port = '3306'/" "$SQLCONF"
          sed -i "s/\\\$login = 'openemr'/\\\$login = '$MYSQL_USER'/" "$SQLCONF"
          sed -i "s/\\\$pass = ''/\\\$pass = '$MYSQL_PASS'/" "$SQLCONF"
          sed -i "s/\\\$dbase = 'openemr'/\\\$dbase = '$MYSQL_DATABASE'/" "$SQLCONF"
          
          # Add root password if not present
          if ! grep -q "\\\$rootpass" "$SQLCONF"; then
            echo "\\\$rootpass = '$MYSQL_ROOT_PASS';" >> "$SQLCONF"
          fi
          
          # Set permissions (NFS may not support chown, so we try but don't fail)
          chmod -R 755 /mnt/sites || true
          
          echo "✓ Configuration complete"
          echo "Created: $SQLCONF"
          
          # Verify the file was created
          if [ -f "$SQLCONF" ]; then
            echo "✓ Initialization successful"
            exit 0
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
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
        }
      }
    }
  }
  
  depends_on = [
    null_resource.import_prod_nfs,
    null_resource.prepare_nfs_directories
  ]
}

resource "null_resource" "execute_prod_init_job" {
  count = var.configure_production_environment && local.nfs_server_exists ? 1 : 0

  triggers = {
    job_id = google_cloud_run_v2_job.prod_init_job[0].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      gcloud run jobs execute ${google_cloud_run_v2_job.prod_init_job[0].name} --region ${local.region} --project ${local.project.project_id} --wait
    EOT
  }
  
  depends_on = [
    google_cloud_run_v2_job.prod_init_job
  ]
}
