# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

#########################################################################
# Directus CMS Preset Configuration
#########################################################################

locals {
  directus_module = {
    app_name        = "directus"
    description     = "Directus - Open Source Headless CMS and Backend-as-a-Service"
    container_image = "directus/directus:11.1.0"
    image_source    = "prebuilt"
    container_port  = 8055
    database_type   = "POSTGRES_15"
    db_name         = "directus"
    db_user         = "directus"

    # Performance optimization
    enable_cloudsql_volume     = false
    cloudsql_volume_mount_path = ""

    # NFS Configuration
    nfs_enabled    = false
    nfs_mount_path = ""

    # GCS volumes for uploads
    gcs_volumes = [
      {
        name          = "directus-uploads"
        mount_path    = "/mnt/directus-uploads"
        read_only     = false
        mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
      }
    ]

    # Resource limits
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "1024Mi"
    }
    min_instance_count = 1
    max_instance_count = 3

    # Container command and args
    container_command = [] # Use default
    container_args    = [] # Use default

    # Environment variables
    environment_variables = {}

    # Initialization Jobs
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Directus Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache postgresql-client

            # Use DB_IP if available (injected by WebApp), else DB_HOST
            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            echo "Waiting for database..."
            export PGPASSWORD=$ROOT_PASSWORD
            until psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; do
              echo "Waiting for database connection at $TARGET_DB_HOST..."
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
            GRANT ALL PRIVILEGES ON DATABASE postgres TO "$DB_USER";
            EOF

            echo "Creating Database $DB_NAME if not exists..."
            if ! psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
              echo "Database does not exist. Creating as $DB_USER..."
              # Create database with owner set to DB_USER
              psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"
            else
              echo "Database $DB_NAME already exists."
              psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"
            fi

            echo "Granting privileges..."
            export PGPASSWORD=$ROOT_PASSWORD
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

            echo "Granting schema permissions (PG15+)..."
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";"

            echo "DB Init complete."
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
      }
    ]

    # PostgreSQL extensions
    enable_postgres_extensions = true
    postgres_extensions        = ["uuid-ossp"]

    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/server/health"
      initial_delay_seconds = 30
      timeout_seconds       = 5
      period_seconds        = 10
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/server/health"
      initial_delay_seconds = 30
      timeout_seconds       = 5
      period_seconds        = 15
      failure_threshold     = 3
    }
  }
}

output "directus_module" {
  description = "directus application module configuration"
  value       = local.directus_module
}
