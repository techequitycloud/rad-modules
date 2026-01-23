# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  plane_module = {
    app_name        = "plane"
    description     = "Plane - Open Source Project Management Tool"
    container_image = "artifacts.plane.so/makeplane/plane-aio-commercial:stable"
    application_version = "stable"
    image_source    = "prebuilt"
    container_port  = 80
    database_type   = "POSTGRES_15"
    db_name         = "plane"
    db_user         = "plane"
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    # Storage - Handled via S3 compatibility in main.tf (HMAC keys)
    # We do NOT mount GCS volumes as files here because we use S3 API.
    gcs_volumes = []

    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 1
    max_instance_count = 3

    environment_variables = {
      PGPORT               = "5432"
      # Redis and RabbitMQ are internal in AIO image
      REDIS_HOST           = "localhost"
      REDIS_PORT           = "6379"
      # Plane specific configuration
      ENABLE_SIGNUP        = "true"
      # WEB_URL and CORS_ALLOWED_ORIGINS are injected dynamically in main.tf
    }

    enable_postgres_extensions = true
    postgres_extensions        = ["pg_trgm", "uuid-ossp"]

    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Plane Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "=== Plane Database Setup ==="
            apk update && apk add --no-cache postgresql-client

            # Use DB_IP if available, else DB_HOST
            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            echo "Waiting for database..."
            export PGPASSWORD=$ROOT_PASSWORD
            until psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; do
              echo "Waiting for database connection..."
              sleep 2
            done

            echo "Creating Role $DB_USER if not exists..."
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres <<EOF
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
            ALTER ROLE "$DB_USER" INHERIT;
            GRANT ALL PRIVILEGES ON DATABASE postgres TO "$DB_USER";
            EOF

            echo "Creating Database $DB_NAME if not exists..."
            if ! psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
              echo "Database does not exist. Creating as postgres..."
              psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "CREATE DATABASE \"$DB_NAME\";"
            else
              echo "Database $DB_NAME already exists."
            fi

            echo "Configuring ownership and permissions..."
            # Ensure app user owns the database
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"

            # Grant schema permissions (crucial for PG15+ public schema)
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";"

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
      timeout_seconds       = 5
      period_seconds        = 10
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 90
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
  }
}

output "plane_module" {
  description = "Plane application module configuration"
  value       = local.plane_module
}
