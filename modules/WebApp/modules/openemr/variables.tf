# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  openemr_module = {
    app_name        = "openemr"
    description     = "OpenEMR - Electronic health records and medical practice management"
    container_image = "openemr/openemr:7.0.3"
    image_source    = "prebuilt"
    container_port  = 80
    database_type   = "MYSQL_8_0"
    db_name         = "openemr"
    db_user         = "openemr"
    
    # Backup Configuration
    enable_backup_import = true
    backup_source        = "gdrive"
    backup_uri           = null

    enable_cloudsql_volume     = false

    # NFS Configuration (Preferred for OpenEMR sites folder due to file locking)
    nfs_enabled    = true
    nfs_mount_path = "/var/www/localhost/htdocs/openemr/sites"

    # Note: GCS volume removed in favor of NFS for sites directory to match proven WebApp preset
    gcs_volumes = []

    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 1
    max_instance_count = 1
    environment_variables = {}
    enable_mysql_plugins = false
    mysql_plugins        = []

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 240
      timeout_seconds       = 60
      period_seconds        = 240
      failure_threshold     = 5
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/interface/login/login.php"
      initial_delay_seconds = 300
      timeout_seconds       = 60
      period_seconds        = 60
      failure_threshold     = 3
    }

    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache mysql-client netcat-openbsd

            # Use DB_IP if available, else DB_HOST.
            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            echo "Waiting for database..."
            until nc -z $TARGET_DB_HOST 3306; do
              echo "Waiting for MySQL port 3306..."
              sleep 2
            done

            cat > ~/.my.cnf << EOF
[client]
user=root
password=$ROOT_PASSWORD
host=$TARGET_DB_HOST
EOF
            chmod 600 ~/.my.cnf

            echo "Creating User $DB_USER if not exists..."
            mysql --defaults-file=~/.my.cnf <<EOF
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
FLUSH PRIVILEGES;
EOF

            echo "Creating Database $DB_NAME if not exists..."
            mysql --defaults-file=~/.my.cnf -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"

            echo "Granting privileges..."
            mysql --defaults-file=~/.my.cnf <<EOF
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

            rm -f ~/.my.cnf
            echo "DB Init complete."
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
      },
      {
        name             = "openemr-nfs-setup"
        description      = "Setup OpenEMR NFS sites directory and config"
        image            = "alpine:3.19"
        command          = ["/bin/sh"]
        script_path      = "${path.module}/../../scripts/openemr-nfs-setup.sh"
        execute_on_apply = true
        mount_nfs        = true
        env_vars = {
          NFS_MOUNT_PATH = "/var/www/localhost/htdocs/openemr/sites"
        }
      }
    ]
  }
}

output "openemr_module" {
  description = "openemr application module configuration"
  value       = local.openemr_module
}
