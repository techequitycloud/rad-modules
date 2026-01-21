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

    # Initialization jobs
    initialization_jobs = [
      {
        name             = "db-init"
        description      = "Initialize WordPress database and user"
        image            = "alpine:3.19"
        execute_on_apply = true
        command          = ["/bin/sh", "-c"]
        args = [<<-EOT
          set -e
          echo "Starting DB Import/Init Job"

          # Use WORDPRESS_DB_HOST as DB_HOST if DB_HOST is not set (Cloud SQL IP)
          DB_HOST=$${DB_HOST:-$WORDPRESS_DB_HOST}

          echo "DB_HOST: $DB_HOST"

          # Install required packages
          apk add --no-cache mysql-client netcat-openbsd

          # Create MySQL configuration file
          echo "[client]" > ~/.my.cnf
          echo "user=root" >> ~/.my.cnf
          echo "password=$ROOT_PASSWORD" >> ~/.my.cnf
          echo "host=$DB_HOST" >> ~/.my.cnf
          chmod 600 ~/.my.cnf

          # Verify connection
          echo "Verifying MySQL connection..."
          mysql --defaults-file=~/.my.cnf -e "SELECT VERSION();"

          # Create User
          echo "Creating User $DB_USER..."
          mysql --defaults-file=~/.my.cnf <<EOF
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
FLUSH PRIVILEGES;
EOF

          # Create Database
          echo "Creating Database $DB_NAME..."
          mysql --defaults-file=~/.my.cnf -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

          # Grant Privileges
          echo "Granting Privileges..."
          mysql --defaults-file=~/.my.cnf <<EOF
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
GRANT GRANT OPTION ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF
          echo "DB Init Job Completed Successfully"
        EOT
        ]
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
