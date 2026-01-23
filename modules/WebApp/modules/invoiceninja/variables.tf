# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

#########################################################################
# Invoice Ninja Preset Configuration
#########################################################################

locals {
  invoiceninja_module = {
    app_name        = "invoiceninja"
    description     = "Invoice Ninja - Invoicing & Payments"
    container_image = "invoiceninja/invoiceninja:5"
    image_source    = "custom"
    container_port  = 80

    container_build_config = {
      enabled            = true
      context_path       = "invoiceninja"
      dockerfile_path    = "Dockerfile"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = "webapp-repo"
    }
    database_type   = "MYSQL_8_0"
    db_name         = "invoiceninja"
    db_user         = "invoiceninja"

    # Performance optimization
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/mysqld"

    # Storage volumes
    gcs_volumes = [
      {
        name          = "invoiceninja-storage"
        mount_path    = "/var/www/app/storage"
        read_only     = false
        # Updated mount options for better security and GCSFuse compatibility
        mount_options = [
          "implicit-dirs",
          "metadata-cache-ttl-secs=60",
          "uid=1000",
          "gid=1000",
          "file-mode=666",
          "dir-mode=777"
        ]
      }
    ]

    # Resource limits
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "1Gi"
    }
    min_instance_count = 1
    max_instance_count = 3

    # Environment variables
    environment_variables = {
      APP_ENV       = "production"
      APP_DEBUG     = "false"
      DB_TYPE       = "mysql"
      IN_USER_EMAIL = "admin@example.com"
      LOG_CHANNEL   = "stderr"
      # DB_HOST, DB_DATABASE, DB_USERNAME, DB_PASSWORD will be injected by main.tf
      # APP_URL, TRUSTED_PROXIES will be injected by main.tf
      # APP_KEY will be injected by main.tf
      # IN_PASSWORD will be injected by main.tf
    }

    # Initialization Jobs
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Invoice Ninja Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache mysql-client netcat-openbsd

            # Use DB_IP if available, else DB_HOST
            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            # Check if TARGET_DB_HOST is set
            if [ -z "$TARGET_DB_HOST" ]; then
              echo "Error: DB_HOST is not set."
              exit 1
            fi

            # DB_PASSWORD and ROOT_PASSWORD are automatically injected by WebApp/jobs.tf
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
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 180
      timeout_seconds       = 10
      period_seconds        = 10
      failure_threshold     = 30
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
  }
}

output "invoiceninja_module" {
  description = "invoiceninja application module configuration"
  value       = local.invoiceninja_module
}
