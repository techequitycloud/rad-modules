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

resource "google_cloud_run_v2_job" "dev_backup_service" {
  count      = var.configure_backups && var.configure_development_environment ? 1 : 0  # Updated count condition
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
          bucket = "${local.backup_bucket_name}"  # Replace with your GCS bucket name
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
  count      = var.configure_backups && var.configure_nonproduction_environment ? 1 : 0  # Updated count condition
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
          bucket = "${local.backup_bucket_name}"  # Replace with your GCS bucket name
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
  count      = var.configure_backups && var.configure_production_environment ? 1 : 0  # Updated count condition
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
          bucket = "${local.backup_bucket_name}"  # Replace with your GCS bucket name
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

# Initialization Job
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
      
      containers {
        image = "openemr/openemr:7.0.3"

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

        command = ["/bin/sh", "-c"]
        args = [<<EOT
          set -e
          echo "Checking /mnt/sites..."
          # If /mnt/sites/default/sqlconf.php does not exist, we initialize.
          if [ ! -f /mnt/sites/default/sqlconf.php ]; then
            echo "Populating /mnt/sites..."
            # Check if /mnt/sites is empty, if so copy all. If not empty but missing sqlconf, copy might fail or be partial.
            # Assuming if sqlconf missing, it's safe to copy.
            cp -R /var/www/localhost/htdocs/openemr/sites/. /mnt/sites/ || true
            
            echo "Configuring sqlconf.php..."
            SQLCONF="/mnt/sites/default/sqlconf.php"
            
            if [ -f "$SQLCONF" ]; then
              sed -i "s/\$host\s*=\s*'[^']*'/\$host = '${local.db_internal_ip}'/" "$SQLCONF"
              sed -i "s/\$port\s*=\s*'[^']*'/\$port = '3306'/" "$SQLCONF"
              sed -i "s/\$login\s*=\s*'[^']*'/\$login = '$MYSQL_USER'/" "$SQLCONF"
              sed -i "s/\$pass\s*=\s*'[^']*'/\$pass = '$MYSQL_PASS'/" "$SQLCONF"
              sed -i "s/\$dbase\s*=\s*'[^']*'/\$dbase = '$MYSQL_DATABASE'/" "$SQLCONF"
              
              # Add rootpass only if it's not there, though usually it's not needed in sqlconf.php for runtime but import_nfs does it.
              # We will add it to be consistent with import_nfs.tpl
              if ! grep -q "\$rootpass" "$SQLCONF"; then
                 sed -i "/\$pass\s*=\s*'[^']*'/a \$rootpass = '$MYSQL_ROOT_PASS';" "$SQLCONF"
              fi
              
              # Fix permissions
              chown -R 1000:1000 /mnt/sites || true
              chmod -R 755 /mnt/sites || true
              echo "Configuration done."
            else
               echo "Error: sqlconf.php not found after copy."
               exit 1
            fi
          else
            echo "/mnt/sites/default/sqlconf.php exists. Skipping initialization."
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
    null_resource.import_dev_nfs
  ]
}

resource "null_resource" "execute_dev_init_job" {
  count = var.configure_development_environment && local.nfs_server_exists ? 1 : 0

  triggers = {
    # Run only on creation of the job or if job definition changes
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

# QA Init Job
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
      
      containers {
        image = "openemr/openemr:7.0.3"

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

        command = ["/bin/sh", "-c"]
        args = [<<EOT
          set -e
          echo "Checking /mnt/sites..."
          if [ ! -f /mnt/sites/default/sqlconf.php ]; then
            echo "Populating /mnt/sites..."
            cp -R /var/www/localhost/htdocs/openemr/sites/. /mnt/sites/ || true
            
            echo "Configuring sqlconf.php..."
            SQLCONF="/mnt/sites/default/sqlconf.php"
            
            if [ -f "$SQLCONF" ]; then
              sed -i "s/\$host\s*=\s*'[^']*'/\$host = '${local.db_internal_ip}'/" "$SQLCONF"
              sed -i "s/\$port\s*=\s*'[^']*'/\$port = '3306'/" "$SQLCONF"
              sed -i "s/\$login\s*=\s*'[^']*'/\$login = '$MYSQL_USER'/" "$SQLCONF"
              sed -i "s/\$pass\s*=\s*'[^']*'/\$pass = '$MYSQL_PASS'/" "$SQLCONF"
              sed -i "s/\$dbase\s*=\s*'[^']*'/\$dbase = '$MYSQL_DATABASE'/" "$SQLCONF"
              
              if ! grep -q "\$rootpass" "$SQLCONF"; then
                 sed -i "/\$pass\s*=\s*'[^']*'/a \$rootpass = '$MYSQL_ROOT_PASS';" "$SQLCONF"
              fi
              
              chown -R 1000:1000 /mnt/sites || true
              chmod -R 755 /mnt/sites || true
              echo "Configuration done."
            else
               echo "Error: sqlconf.php not found after copy."
               exit 1
            fi
          else
            echo "/mnt/sites/default/sqlconf.php exists. Skipping initialization."
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
    null_resource.import_qa_nfs
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

# Prod Init Job
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
      
      containers {
        image = "openemr/openemr:7.0.3"

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

        command = ["/bin/sh", "-c"]
        args = [<<EOT
          set -e
          echo "Checking /mnt/sites..."
          if [ ! -f /mnt/sites/default/sqlconf.php ]; then
            echo "Populating /mnt/sites..."
            cp -R /var/www/localhost/htdocs/openemr/sites/. /mnt/sites/ || true
            
            echo "Configuring sqlconf.php..."
            SQLCONF="/mnt/sites/default/sqlconf.php"
            
            if [ -f "$SQLCONF" ]; then
              sed -i "s/\$host\s*=\s*'[^']*'/\$host = '${local.db_internal_ip}'/" "$SQLCONF"
              sed -i "s/\$port\s*=\s*'[^']*'/\$port = '3306'/" "$SQLCONF"
              sed -i "s/\$login\s*=\s*'[^']*'/\$login = '$MYSQL_USER'/" "$SQLCONF"
              sed -i "s/\$pass\s*=\s*'[^']*'/\$pass = '$MYSQL_PASS'/" "$SQLCONF"
              sed -i "s/\$dbase\s*=\s*'[^']*'/\$dbase = '$MYSQL_DATABASE'/" "$SQLCONF"
              
              if ! grep -q "\$rootpass" "$SQLCONF"; then
                 sed -i "/\$pass\s*=\s*'[^']*'/a \$rootpass = '$MYSQL_ROOT_PASS';" "$SQLCONF"
              fi
              
              chown -R 1000:1000 /mnt/sites || true
              chmod -R 755 /mnt/sites || true
              echo "Configuration done."
            else
               echo "Error: sqlconf.php not found after copy."
               exit 1
            fi
          else
            echo "/mnt/sites/default/sqlconf.php exists. Skipping initialization."
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
    null_resource.import_prod_nfs
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
