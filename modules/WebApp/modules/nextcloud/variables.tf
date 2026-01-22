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
    db_name         = "nextcloud_db"
    db_user         = "nextcloud_user"

    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/postgresql"

    gcs_volumes = [
      {
        bucket     = "$${tenant_id}-nextcloud-data"
        mount_path = "/var/www/html/data"
        read_only  = false
      },
      {
        bucket     = "$${tenant_id}-nextcloud-config"
        mount_path = "/var/www/html/config"
        read_only  = false
      }
    ]
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 1
    max_instance_count = 10
    environment_variables = {
      POSTGRES_HOST = "/var/run/postgresql"
    }
    enable_postgres_extensions = false
    postgres_extensions         = []

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

            # Use DB_IP if set, otherwise DB_HOST
            TARGET_DB_HOST=$${DB_IP:-$DB_HOST}
            echo "Using DB Host: $TARGET_DB_HOST"

            echo "Waiting for database..."
            export PGPASSWORD=$ROOT_PASSWORD
            until psql -h $TARGET_DB_HOST -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; do
              echo "Waiting for database connection..."
              sleep 2
            done

            echo "Creating Role $DB_USER if not exists..."
            psql -h $TARGET_DB_HOST -p 5432 -U postgres -d postgres <<EOF
            DO \$\$
            BEGIN
              IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
                CREATE ROLE "$DB_USER" WITH LOGIN PASSWORD '$DB_PASSWORD';
              ELSE
                ALTER ROLE "$DB_USER" WITH PASSWORD '$DB_PASSWORD';
              END IF;
            END
            \$\$;
            ALTER ROLE "$DB_USER" CREATEDB;
            GRANT ALL PRIVILEGES ON DATABASE postgres TO "$DB_USER";
            EOF

            echo "Creating Database $DB_NAME if not exists..."
            if ! psql -h $TARGET_DB_HOST -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
              echo "Database does not exist. Creating as $DB_USER..."
              export PGPASSWORD=$DB_PASSWORD
              psql -h $TARGET_DB_HOST -p 5432 -U $DB_USER -d postgres -c "CREATE DATABASE \"$DB_NAME\";"
            else
              echo "Database $DB_NAME already exists."
            fi

            echo "Granting privileges..."
            export PGPASSWORD=$ROOT_PASSWORD
            psql -h $TARGET_DB_HOST -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

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
