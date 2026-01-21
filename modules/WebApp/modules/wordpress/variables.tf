# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

#########################################################################
# WordPress CMS Preset Configuration
#########################################################################

locals {
  wordpress_module = {
    app_name        = "wp"
    description     = "WordPress CMS - Popular content management system for websites and blogs"
    container_image = "wordpress:6.8.1-apache"
    image_source    = "prebuilt"
    container_port  = 80
    database_type   = "MYSQL_8_0"
    db_name         = "wp"
    db_user         = "wp"
    application_version = "6.8.1"
    application_sha     = "52d5f05c96a9155f78ed84700264307e5dea14b4"

    # Performance optimization
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/mysqld"

    # Storage volumes
    gcs_volumes = [{
      name       = "wp-uploads"
      mount_path = "/var/www/html/wp-content"
      read_only  = false
      mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
    }]

    # Resource limits
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "2Gi"
    }
    min_instance_count = 1
    max_instance_count = 3 

    # Environment variables
    environment_variables = {
      WORDPRESS_DB_HOST      = "localhost:/var/run/mysqld/mysqld.sock"
      WORDPRESS_TABLE_PREFIX = "wp_"
      WORDPRESS_DEBUG        = "false"
    }

    # MySQL plugins
    enable_mysql_plugins = false
    mysql_plugins        = []

    # Initialization Jobs
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create WordPress Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache mysql-client netcat-openbsd

            # Use WORDPRESS_DB_HOST which is available in static envs (mapped to internal IP)
            DB_HOST_VAL=$WORDPRESS_DB_HOST
            echo "Using DB Host: $DB_HOST_VAL"

            # Check if DB_HOST_VAL is set
            if [ -z "$DB_HOST_VAL" ]; then
              echo "Error: WORDPRESS_DB_HOST is not set."
              exit 1
            fi

            # DB_PASSWORD and ROOT_PASSWORD are automatically injected by WebApp/jobs.tf
            if [ -z "$DB_PASSWORD" ]; then
              echo "Error: DB_PASSWORD is not set. It should be injected by WebApp/jobs.tf."
              exit 1
            fi

            if [ -z "$ROOT_PASSWORD" ]; then
              echo "Error: ROOT_PASSWORD is not set. It should be injected by WebApp/jobs.tf."
              exit 1
            fi

            echo "Waiting for database..."
            until nc -z $DB_HOST_VAL 3306; do
              echo "Waiting for MySQL port 3306..."
              sleep 2
            done

            cat > ~/.my.cnf << EOF
[client]
user=root
password=$ROOT_PASSWORD
host=$DB_HOST_VAL
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
      }
    ]

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 240
      timeout_seconds       = 60
      period_seconds        = 240
      failure_threshold     = 1
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/wp-admin/install.php"
      initial_delay_seconds = 300
      timeout_seconds       = 60
      period_seconds        = 60
      failure_threshold     = 3
    }
  }
}

output "wordpress_module" {
  description = "wordpress application module configuration"
  value       = local.wordpress_module
}
