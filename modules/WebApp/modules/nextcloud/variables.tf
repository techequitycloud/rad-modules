# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  nextcloud_module = {
    app_name        = "nextcloud"
    description     = "Nextcloud File Sync and Share - Self-hosted collaboration platform"
    container_image = "nextcloud:28-apache"
    image_source    = "prebuilt"
    container_port  = 80
    database_type   = "POSTGRES_15"
    db_name         = "nextcloud"
    db_user         = "nextcloud"

    # Performance optimization: Use Unix socket for main app
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/postgresql"

    # Storage volumes
    gcs_volumes = [
      {
        name       = "nextcloud-data"
        bucket     = "$${tenant_id}-nextcloud-data"
        mount_path = "/var/www/html/data"
        read_only  = false
        mount_options = ["implicit-dirs", "uid=33", "gid=33", "file-mode=644", "dir-mode=755", "metadata-cache-ttl-secs=60"]
      },
      {
        name       = "nextcloud-config"
        bucket     = "$${tenant_id}-nextcloud-config"
        mount_path = "/var/www/html/config"
        read_only  = false
        mount_options = ["implicit-dirs", "uid=33", "gid=33", "file-mode=644", "dir-mode=755", "metadata-cache-ttl-secs=60"]
      },
      {
        name       = "nextcloud-apps"
        bucket     = "$${tenant_id}-nextcloud-apps"
        mount_path = "/var/www/html/custom_apps"
        read_only  = false
        mount_options = ["implicit-dirs", "uid=33", "gid=33", "file-mode=644", "dir-mode=755", "metadata-cache-ttl-secs=60"]
      }
    ]

    # Resource limits
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 1
    max_instance_count = 10

    # Environment variables
    # POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, NEXTCLOUD_ADMIN_USER, NEXTCLOUD_ADMIN_PASSWORD
    # are injected by main.tf presets.
    environment_variables = {
      POSTGRES_HOST = "/var/run/postgresql" # Use socket
      # Reverse proxy configuration for Cloud Run
      TRUSTED_PROXIES = "10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.1.1/32"
      OVERWRITEPROTOCOL = "https"
    }

    # Initialization Jobs
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Nextcloud Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache postgresql-client

            # Map variables safely (prefer POSTGRES_* but fallback to DB_*)
            TARGET_DB_USER="$${POSTGRES_USER:-$${DB_USER}}"
            TARGET_DB_NAME="$${POSTGRES_DB:-$${DB_NAME}}"
            # DB_PASSWORD and ROOT_PASSWORD are injected by jobs.tf

            echo "Checking variables..."
            if [ -z "$ROOT_PASSWORD" ]; then
              echo "Error: ROOT_PASSWORD is not set."
              exit 1
            fi
            if [ -z "$DB_PASSWORD" ]; then
              echo "Error: DB_PASSWORD is not set."
              exit 1
            fi
            if [ -z "$DB_HOST" ]; then
              echo "Error: DB_HOST is not set."
              exit 1
            fi

            echo "Waiting for database..."
            export PGHOST=$DB_HOST
            export PGPORT=5432
            export PGPASSWORD=$ROOT_PASSWORD

            until psql -U postgres -d postgres -c '\l' > /dev/null 2>&1; do
              echo "Waiting for database connection at $DB_HOST..."
              sleep 2
            done

            echo "Creating Role $TARGET_DB_USER if not exists..."
            psql -U postgres -d postgres <<EOF
            DO \$\$
            BEGIN
              IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$TARGET_DB_USER') THEN
                CREATE ROLE "$TARGET_DB_USER" WITH LOGIN PASSWORD '$DB_PASSWORD';
              ELSE
                ALTER ROLE "$TARGET_DB_USER" WITH PASSWORD '$DB_PASSWORD';
              END IF;
            END
            \$\$;
            ALTER ROLE "$TARGET_DB_USER" CREATEDB;
            GRANT ALL PRIVILEGES ON DATABASE postgres TO "$TARGET_DB_USER";
            EOF

            echo "Creating Database $TARGET_DB_NAME if not exists..."
            if ! psql -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$TARGET_DB_NAME'" | grep -q 1; then
              echo "Database does not exist. Creating as $TARGET_DB_USER..."
              export PGPASSWORD=$DB_PASSWORD
              psql -U $TARGET_DB_USER -d postgres -c "CREATE DATABASE \"$TARGET_DB_NAME\";"
            else
              echo "Database $TARGET_DB_NAME already exists."
            fi

            echo "Granting privileges..."
            export PGPASSWORD=$ROOT_PASSWORD
            psql -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$TARGET_DB_NAME\" TO \"$TARGET_DB_USER\";"

            echo "DB Init complete."
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
      }
    ]

    enable_postgres_extensions = false
    postgres_extensions         = []

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 60
      timeout_seconds       = 30
      period_seconds        = 60
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/status.php"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 60
      failure_threshold     = 3
    }
  }
}

output "nextcloud_module" {
  description = "nextcloud application module configuration"
  value       = local.nextcloud_module
}
