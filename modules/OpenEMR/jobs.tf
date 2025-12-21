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
  name     = "prep-nfs-${var.application_name}${var.tenant_deployment_id}${local.random_id}"
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
          echo "Creating directory structure..."
          
          # Create all required directories
          mkdir -p /var/www/localhost/htdocs/openemr/sites/default
          mkdir -p /var/www/localhost/htdocs/openemr/sites/default/documents
          mkdir -p /var/www/localhost/htdocs/openemr/sites/dev
          
          # Set permissions - make everything accessible
          chmod -R 777 /var/www/localhost/htdocs/openemr/sites
          
          echo "✓ Directories created successfully:"
          ls -la /var/www/localhost/htdocs/openemr/sites/
          
          echo "✓ NFS directory preparation complete"
        EOT
        ]
        
        volume_mounts {
          name       = "nfs"
          mount_path = "/var/www/localhost/htdocs/openemr/sites"
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
        name = "nfs"
        nfs {
          server = local.nfs_internal_ip
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
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
# Initialization Jobs
# ============================================================================

# Initialization Job
resource "google_cloud_run_v2_job" "init_job" {
  count      = var.configure_environment && local.nfs_server_exists ? 1 : 0
  project    = local.project.project_id
  name       = "init${var.application_name}${var.tenant_deployment_id}${local.random_id}"
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
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        }

        env {
          name  = "MYSQL_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        }

        env {
          name = "MYSQL_PASS"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}-password-${var.tenant_deployment_id}-${local.random_id}"
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
          mount_path = "/var/www/localhost/htdocs/openemr/sites"
        }

        command = ["/bin/sh"]
        args = [
          "-c",
          <<-EOT
          set -e
          
          echo "=== NFS Initialization Script ==="
          echo "Environment Check:"
          echo "  MYSQL_HOST: $MYSQL_HOST"
          echo "  MYSQL_DATABASE: $MYSQL_DATABASE"
          echo "  MYSQL_USER: $MYSQL_USER"
          echo "  MYSQL_PORT: $MYSQL_PORT"
          
          SITES_PATH="/var/www/localhost/htdocs/openemr/sites"
          
          echo "Checking $SITES_PATH..."
          
          # Verify NFS mount is accessible
          if ! ls $SITES_PATH > /dev/null 2>&1; then
            echo "ERROR: Cannot access $SITES_PATH - NFS mount may have failed"
            exit 1
          fi
          
          # Check if already initialized
          if [ -f $SITES_PATH/default/sqlconf.php ] && [ -f $SITES_PATH/default/config.php ]; then
            echo "✓ Configuration files exist. Verifying permissions..."
            
            # Fix permissions even if files exist
            chmod -R 777 $SITES_PATH
            chmod 644 $SITES_PATH/default/sqlconf.php 2>/dev/null || true
            chmod 644 $SITES_PATH/default/config.php 2>/dev/null || true
            
            echo "✓ Permissions verified. Skipping initialization."
            exit 0
          fi
          
          echo "Initializing NFS share..."
          
          # Create directory structure with correct permissions
          mkdir -p $SITES_PATH/default
          mkdir -p $SITES_PATH/default/documents
          mkdir -p $SITES_PATH/dev
          
          # Set permissions immediately after creation
          chmod -R 777 $SITES_PATH
          
          # Install required packages
          echo "Installing required packages..."
          apk update
          apk add --no-cache php81 php81-cli
          
          # Verify PHP installation
          echo "Verifying PHP installation..."
          if ! command -v php81 >/dev/null 2>&1; then
            echo "ERROR: PHP installation failed"
            exit 1
          fi
          echo "✓ PHP installed successfully: $(php81 --version | head -n1)"
          
          # Create sqlconf.php
          echo "Creating sqlconf.php configuration file..."
          cat > $SITES_PATH/default/sqlconf.php << 'SQLCONF_EOF'
<?php
//  OpenEMR
//  MySQL Config

global $disable_utf8_flag;
$disable_utf8_flag = false;

$host = 'DBHOST_PLACEHOLDER';
$port = '3306';
$login = 'DBUSER_PLACEHOLDER';
$pass = 'DBPASS_PLACEHOLDER';
$dbase = 'DBNAME_PLACEHOLDER';
$db_encoding = 'utf8mb4';

$sqlconf = array();
global $sqlconf;
$sqlconf["host"]= $host;
$sqlconf["port"] = $port;
$sqlconf["login"] = $login;
$sqlconf["pass"] = $pass;
$sqlconf["dbase"] = $dbase;
$sqlconf["db_encoding"] = $db_encoding;

//////////////////////////
//////////////////////////
//////////////////////////
//////DO NOT TOUCH THIS///
$config = 1; /////////////
//////////////////////////
//////////////////////////
//////////////////////////
?>
SQLCONF_EOF
          
          # Replace placeholders in sqlconf.php
          echo "Configuring database connection in sqlconf.php..."
          sed -i "s|DBHOST_PLACEHOLDER|$MYSQL_HOST|g" $SITES_PATH/default/sqlconf.php
          sed -i "s|DBUSER_PLACEHOLDER|$MYSQL_USER|g" $SITES_PATH/default/sqlconf.php
          sed -i "s|DBPASS_PLACEHOLDER|$MYSQL_PASS|g" $SITES_PATH/default/sqlconf.php
          sed -i "s|DBNAME_PLACEHOLDER|$MYSQL_DATABASE|g" $SITES_PATH/default/sqlconf.php
          
          # Create config.php
          echo "Creating config.php configuration file..."
          cat > $SITES_PATH/default/config.php << 'CONFIG_EOF'
<?php
// OpenEMR Configuration File

$GLOBALS['OE_SITE_DIR'] = '/var/www/localhost/htdocs/openemr/sites/default';
$GLOBALS['OE_SITES_BASE'] = '/var/www/localhost/htdocs/openemr/sites';

// Database configuration
$GLOBALS['host'] = 'DBHOST_PLACEHOLDER';
$GLOBALS['port'] = '3306';
$GLOBALS['login'] = 'DBUSER_PLACEHOLDER';
$GLOBALS['pass'] = 'DBPASS_PLACEHOLDER';
$GLOBALS['dbase'] = 'DBNAME_PLACEHOLDER';
$GLOBALS['db_encoding'] = 'utf8mb4';

// Site configuration
$GLOBALS['site_id_header_name'] = 'default';
$GLOBALS['webserver_root'] = '/var/www/localhost/htdocs/openemr';
$GLOBALS['web_root'] = '';

// Disable setup
$GLOBALS['disable_setup'] = 1;

?>
CONFIG_EOF
          
          # Replace placeholders in config.php
          echo "Configuring database connection in config.php..."
          sed -i "s|DBHOST_PLACEHOLDER|$MYSQL_HOST|g" $SITES_PATH/default/config.php
          sed -i "s|DBUSER_PLACEHOLDER|$MYSQL_USER|g" $SITES_PATH/default/config.php
          sed -i "s|DBPASS_PLACEHOLDER|$MYSQL_PASS|g" $SITES_PATH/default/config.php
          sed -i "s|DBNAME_PLACEHOLDER|$MYSQL_DATABASE|g" $SITES_PATH/default/config.php
          
          # Set final permissions
          chmod 644 $SITES_PATH/default/sqlconf.php || true
          chmod 644 $SITES_PATH/default/config.php || true
          chmod 755 $SITES_PATH/default || true
          chmod 755 $SITES_PATH || true
          chmod 777 $SITES_PATH/default/documents || true
          
          echo "✓ Configuration complete"
          
          # Verify files were created and validate PHP syntax
          echo "=== Verifying sqlconf.php ==="
          if [ -f $SITES_PATH/default/sqlconf.php ]; then
            echo "✓ sqlconf.php created successfully"
            cat $SITES_PATH/default/sqlconf.php
            
            if php81 -l $SITES_PATH/default/sqlconf.php; then
              echo "✓ sqlconf.php syntax validation passed"
            else
              echo "ERROR: sqlconf.php syntax validation failed"
              exit 1
            fi
          else
            echo "ERROR: sqlconf.php was not created"
            exit 1
          fi
          
          echo ""
          echo "=== Verifying config.php ==="
          if [ -f $SITES_PATH/default/config.php ]; then
            echo "✓ config.php created successfully"
            cat $SITES_PATH/default/config.php
            
            if php81 -l $SITES_PATH/default/config.php; then
              echo "✓ config.php syntax validation passed"
            else
              echo "ERROR: config.php syntax validation failed"
              exit 1
            fi
          else
            echo "ERROR: config.php was not created"
            exit 1
          fi
          
          echo ""
          echo "=== Final directory structure ==="
          ls -la $SITES_PATH/default/
          
          echo "✓ Initialization successful"
          exit 0
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
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        }
      }
    }
  }
  
  depends_on = [
    null_resource.import_nfs,
    null_resource.execute_prepare_nfs
  ]
}

resource "null_resource" "execute_init_job" {
  count = var.configure_environment && local.nfs_server_exists ? 1 : 0

  triggers = {
    job_id = google_cloud_run_v2_job.init_job[0].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      gcloud run jobs execute ${google_cloud_run_v2_job.init_job[0].name} --region ${local.region} --project ${local.project.project_id} --wait
    EOT
  }
  
  depends_on = [
    google_cloud_run_v2_job.init_job
  ]
}

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
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
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
        args = ["-c", file("${path.module}/scripts/app/import_db_job.sh")]
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
    data.google_secret_manager_secret_version.db_password
  ]
}
