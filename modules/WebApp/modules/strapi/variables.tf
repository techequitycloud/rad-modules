# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

#########################################################################
# Strapi Preset Configuration
#########################################################################

locals {
  strapi_module = {
    app_name        = "strapi"
    description     = "Strapi - Open source Node.js Headless CMS"
    container_image = "strapi/strapi:latest"
    image_source    = "prebuilt"
    container_port  = 1337
    database_type   = "POSTGRES_15"
    db_name         = "strapi"
    db_user         = "strapi"

    # Performance optimization
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/postgresql"

    # Storage volumes
    gcs_volumes = [{
      name       = "strapi-uploads"
      mount_path = "/srv/app/public/uploads"
      read_only  = false
      mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
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
      # Database Connection
      DATABASE_CLIENT   = "postgres"
      DATABASE_HOST     = "/var/run/postgresql" # Socket
      DATABASE_PORT     = "5432"
      DATABASE_NAME     = "strapi"
      DATABASE_USERNAME = "strapi"
      DATABASE_SSL      = "false"

      # Strapi Configuration
      NODE_ENV          = "production"

      # Secrets (injected via main.tf)
      # DATABASE_PASSWORD
      # JWT_SECRET
      # API_TOKEN_SALT
      # ADMIN_JWT_SECRET
      # APP_KEYS
      # TRANSFER_TOKEN_SALT
    }

    # Initialization Jobs
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Strapi Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache postgresql-client

            # Use DB_IP if available (TCP), else fallback to DB_HOST
            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            if [ -z "$ROOT_PASSWORD" ]; then
              echo "Error: ROOT_PASSWORD is not set."
              exit 1
            fi
            if [ -z "$DB_PASSWORD" ]; then
              echo "Error: DB_PASSWORD is not set."
              exit 1
            fi

            echo "Waiting for database..."
            export PGPASSWORD=$ROOT_PASSWORD
            # Initialize connection check
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
              export PGPASSWORD=$DB_PASSWORD
              psql -h "$TARGET_DB_HOST" -p 5432 -U $DB_USER -d postgres -c "CREATE DATABASE \"$DB_NAME\";"
            else
              echo "Database $DB_NAME already exists."
            fi

            echo "Granting privileges..."
            export PGPASSWORD=$ROOT_PASSWORD
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

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
      timeout_seconds       = 10
      period_seconds        = 10
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

output "strapi_module" {
  description = "strapi application module configuration"
  value       = local.strapi_module
}
