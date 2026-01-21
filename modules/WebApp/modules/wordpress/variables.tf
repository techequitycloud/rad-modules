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

    # Initialization Jobs
    initialization_jobs = [
      {
        name             = "db-init"
        description      = "Create WordPress Database and User"
        image            = "alpine:3.19"
        execute_on_apply = true
        command          = ["/bin/sh", "-c"]
        args             = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache mysql-client

            echo "Waiting for database at $WORDPRESS_DB_HOST..."
            # Wait for MySQL to be ready
            until mysql -h "$WORDPRESS_DB_HOST" -u root -p"$ROOT_PASSWORD" -e "SELECT 1"; do
              echo "Waiting for database connection..."
              sleep 2
            done

            echo "Creating Database $WORDPRESS_DB_NAME if not exists..."
            mysql -h "$WORDPRESS_DB_HOST" -u root -p"$ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`$WORDPRESS_DB_NAME\`;"

            echo "Creating User $WORDPRESS_DB_USER if not exists..."
            mysql -h "$WORDPRESS_DB_HOST" -u root -p"$ROOT_PASSWORD" -e "CREATE USER IF NOT EXISTS '$WORDPRESS_DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';"

            echo "Granting privileges..."
            mysql -h "$WORDPRESS_DB_HOST" -u root -p"$ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON \`$WORDPRESS_DB_NAME\`.* TO '$WORDPRESS_DB_USER'@'%'; FLUSH PRIVILEGES;"

            echo "DB Init complete."
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
      }
    ]

    # MySQL plugins
    enable_mysql_plugins = false
    mysql_plugins        = []

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
