# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0
#
# Updated: January 2025
# Reason: Bitnami Moodle deprecated on August 28, 2025
# Alternative: Using lthub/moodle (7M+ pulls, actively maintained)

locals {
  moodle_module = {
    app_name        = "moodle"
    description     = "Moodle LMS - Online learning and course management platform"
    
    # ✅ Updated to use working alternative (lthub/moodle)
    # Bitnami Moodle was moved to bitnamilegacy with no future updates
    container_image = "lthub/moodle:latest"
    image_source    = "prebuilt"
    
    # ✅ Updated port - lthub/moodle uses standard HTTP port 80
    container_port  = 80
    
    database_type   = "MYSQL_8_0"
    db_name         = "moodle"
    db_user         = "moodle"

    # Cloud SQL configuration
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/mysqld"

    # NFS Configuration
    nfs_enabled    = true
    nfs_mount_path = "/mnt"

    # GCS Volumes
    # Note: The bucket name will be resolved by main.tf using the name "moodle-data"
    gcs_volumes = [{
      name       = "moodle-data"
      # ✅ Updated mount path for lthub/moodle
      mount_path = "/var/moodledata"
      read_only  = false
    }]

    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "2Gi"
    }
    min_instance_count = 0
    max_instance_count = 3

    # ✅ Updated environment variables for lthub/moodle compatibility
    # Environment variables will be injected by main.tf (Host, Port, User, Pass, etc.)
    environment_variables = {
      # Database configuration (compatible with lthub/moodle)
      MOODLE_DB_TYPE = "mysqli"
      MOODLE_DB_PORT = "3306"
      
      # Site configuration
      MOODLE_SITE_NAME     = "Moodle LMS"
      MOODLE_SITE_FULLNAME = "Moodle Learning Management System"
      MOODLE_ADMIN_USER    = "admin"
      MOODLE_ADMIN_EMAIL   = "admin@example.com"
      
      # Installation settings
      MOODLE_SKIP_INSTALL = "no"
      MOODLE_UPDATE       = "yes"
    }

    enable_mysql_plugins = false
    mysql_plugins        = []

    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Moodle Database and User"
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
            mysql --defaults-file=~/.my.cnf -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

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
      }
    ]

    # ✅ Updated startup probe for lthub/moodle (needs more time to initialize)
    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 180  # Increased for Moodle initialization
      timeout_seconds       = 10
      period_seconds        = 30
      failure_threshold     = 10
    }
    
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 120
      timeout_seconds       = 5
      period_seconds        = 60
      failure_threshold     = 3
    }
  }
}

output "moodle_module" {
  description = "moodle application module configuration"
  value       = local.moodle_module
}
