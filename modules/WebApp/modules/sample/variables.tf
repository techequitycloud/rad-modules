# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  sample_module = {
    app_name        = "sample-app"
    description     = "Sample Custom Application - Flask App with Database Connection"
    container_image = "python:3.11-slim" # Placeholder, actual image is built via custom build
    app_version     = "v1.0.0"
    image_source    = "custom"

    # Custom build configuration
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "sample"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = "webapp-repo"
    }

    container_port  = 8080
    database_type   = "POSTGRES_15"
    db_name         = "sampledb"
    db_user         = "sampleuser"

    # Enable Cloud SQL volume for potential socket connection (though app uses TCP in this sample)
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "512Mi"
    }
    min_instance_count = 0
    max_instance_count = 1

    environment_variables = {
      FLASK_ENV = "production"
    }

    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/healthz"
      initial_delay_seconds = 10
      timeout_seconds       = 5
      period_seconds        = 10
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/healthz"
      initial_delay_seconds = 15
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }

    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Initialize Sample Database"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing postgresql-client..."
            apk update && apk add --no-cache postgresql-client

            # Use DB_IP if available (injected by WebApp), else DB_HOST
            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            echo "Waiting for database..."
            export PGPASSWORD=$ROOT_PASSWORD
            until pg_isready -h "$TARGET_DB_HOST" -p 5432; do
              echo "Waiting for PostgreSQL..."
              sleep 2
            done

            echo "Creating User $DB_USER if not exists..."
            if ! psql -h "$TARGET_DB_HOST" -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
                psql -h "$TARGET_DB_HOST" -U postgres -c "CREATE USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD';"
            else
                psql -h "$TARGET_DB_HOST" -U postgres -c "ALTER USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD';"
            fi

            echo "Creating Database $DB_NAME if not exists..."
            if ! psql -h "$TARGET_DB_HOST" -U postgres -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
                psql -h "$TARGET_DB_HOST" -U postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"
            else
                psql -h "$TARGET_DB_HOST" -U postgres -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"
            fi

            echo "Granting privileges..."
            psql -h "$TARGET_DB_HOST" -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

            echo "Sample DB Init complete."
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
      }
    ]
  }
}

output "sample_module" {
  description = "sample application module configuration"
  value       = local.sample_module
}
