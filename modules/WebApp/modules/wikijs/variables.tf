# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

#########################################################################
# Wiki.js Preset Configuration
#########################################################################

locals {
  wikijs_module = {
    app_name        = "wikijs"
    description     = "Wiki.js - The most powerful and extensible open source Wiki software"
    container_image = "requarks/wiki:2"
    # image_source    = "prebuilt"
    container_port  = 3000
    database_type   = "POSTGRES_15"
    db_name         = "wikijs"
    db_user         = "wikijs"

    # Custom build configuration
    image_source    = "custom"
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "wikijs"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = null
    }

    enable_image_mirroring = true

    # Performance optimization
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/postgresql"

    # Storage volumes - Optional for Local Storage module
    gcs_volumes = [{
      name       = "wikijs-storage"
      mount_path = "/wiki-storage"
      read_only  = false
      mount_options = [
        "implicit-dirs",
        "metadata-cache-ttl-secs=60",
        "file-mode=770",
        "dir-mode=770",
        "uid=1000",
        "gid=1000"
      ]
    }]

    # Resource limits
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "2Gi"
    }
    min_instance_count = 0
    max_instance_count = 3

    # Environment variables
    environment_variables = {
      DB_TYPE            = "postgres"
      DB_PORT            = "5432"
      DB_USER            = "wikijs"
      DB_NAME            = "wikijs"
      DB_SSL             = "false"
      # HA_ACTIVE enables High Availability mode (requires PostgreSQL)
      HA_ACTIVE          = "true"
      # DB_PASS injected via secrets in main.tf
    }

    # PostgreSQL extensions
    enable_postgres_extensions = true
    postgres_extensions        = ["pg_trgm"]

    # Initialization Jobs
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Wiki.js Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache postgresql-client

            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            # Wait for PostgreSQL
            until pg_isready -h "$TARGET_DB_HOST" -p 5432; do
              echo "Waiting for PostgreSQL..."
              sleep 2
            done

            export PGPASSWORD=$ROOT_PASSWORD

            echo "Creating User $DB_USER if not exists..."
            # Check if user exists
            if ! psql -h "$TARGET_DB_HOST" -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
                psql -h "$TARGET_DB_HOST" -U postgres -c "CREATE USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD';"
            else
                psql -h "$TARGET_DB_HOST" -U postgres -c "ALTER USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD';"
            fi

            # Grant user role to postgres to allow setting owner
            echo "Granting role $DB_USER to postgres..."
            psql -h "$TARGET_DB_HOST" -U postgres -c "GRANT \"$DB_USER\" TO postgres;"

            echo "Creating Database $DB_NAME if not exists..."
            # Check if database exists
            if ! psql -h "$TARGET_DB_HOST" -U postgres -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
                psql -h "$TARGET_DB_HOST" -U postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"
            else
                psql -h "$TARGET_DB_HOST" -U postgres -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"
            fi

            echo "Granting privileges..."
            psql -h "$TARGET_DB_HOST" -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

            # Allow user to create schema in public
            psql -h "$TARGET_DB_HOST" -U postgres -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";"

            echo "PostgreSQL DB Init complete."
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
      path                  = "/healthz"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 10
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/healthz"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
  }
}

output "wikijs_module" {
  description = "wikijs application module configuration"
  value       = local.wikijs_module
}
