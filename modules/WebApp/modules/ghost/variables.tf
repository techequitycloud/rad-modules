# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

#########################################################################
# Ghost Preset Configuration
#########################################################################

locals {
  ghost_module = {
    app_name        = "ghost"
    description     = "Ghost - Professional publishing platform"
    container_image = "ghost:5"
    application_version = "5"
    image_source    = "custom"

    # Custom build configuration to handle dynamic URL detection
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "ghost"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = "webapp-repo"
    }

    container_port  = 2368
    database_type   = "MYSQL_8_0"
    db_name         = "ghost"
    db_user         = "ghost"

    # Performance optimization
    enable_cloudsql_volume     = false
    cloudsql_volume_mount_path = "/var/run/mysqld"

    # Storage volumes
    gcs_volumes = [{
      name       = "ghost-content"
      mount_path = "/var/lib/ghost/content"
      read_only  = false
      mount_options = [
        "implicit-dirs",
        "metadata-cache-ttl-secs=60",
        "uid=1000",
        "gid=1000",
        "dir-mode=777",
        "file-mode=666"
      ]
    }]

    # Resource limits
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "1Gi"
    }
    min_instance_count = 1
    max_instance_count = 3

    # Environment variables
    environment_variables = {
      # Ghost Configuration
      url = "http://localhost:2368" # Should be overridden by user with actual domain

      # Database Connection
      database__client = "mysql"
      database__connection__host = "127.0.0.1"
      database__connection__user = "ghost"
      database__connection__database = "ghost"
      # Password injected via secrets in main.tf
    }

    # MySQL plugins
    enable_mysql_plugins = false
    mysql_plugins        = []

    # Initialization Jobs
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Ghost Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache mysql-client netcat-openbsd

            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            if [ -z "$DB_PASSWORD" ]; then
              echo "Error: DB_PASSWORD is not set."
              exit 1
            fi

            if [ -z "$ROOT_PASSWORD" ]; then
              echo "Error: ROOT_PASSWORD is not set."
              exit 1
            fi

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
      }
    ]

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 90
      timeout_seconds       = 10
      period_seconds        = 30
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 60
      timeout_seconds       = 10
      period_seconds        = 30
      failure_threshold     = 3
    }
  }
}

output "ghost_module" {
  description = "ghost application module configuration"
  value       = local.ghost_module
}
