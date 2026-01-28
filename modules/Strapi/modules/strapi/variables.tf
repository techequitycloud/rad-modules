# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

#########################################################################
# Strapi CMS Preset Configuration
#########################################################################

locals {
  strapi_module = {
    app_name        = "strapi"
    description     = "Strapi - Open source Node.js Headless CMS"
    # Strapi requires a custom built image.
    container_image = ""
    image_source    = "build"

    # Custom build configuration
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "."
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = null
    }

    container_port  = 1337
    database_type   = "POSTGRES_15"
    db_name         = "strapi"
    db_user         = "strapi"

    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    # Resource limits
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "1Gi"
    }
    min_instance_count = 0
    max_instance_count = 3

    # Environment variables
    environment_variables = {
      NODE_ENV        = "production"
      DATABASE_CLIENT = "postgres"
      DATABASE_SSL    = "false"
      # DB connection details will be injected by main.tf

      # SMTP Configuration
      SMTP_HOST      = ""
      SMTP_PORT      = "587"
      SMTP_USERNAME  = ""
      # SMTP_PASSWORD should be passed via secrets
      EMAIL_FROM     = ""
      EMAIL_REPLY_TO = ""

      # GCS Configuration
      GCS_PUBLIC_FILES = "true"
      GCS_UNIFORM      = "true"
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

            # Use DB_IP if available, else DB_HOST
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
            GRANT "$DB_USER" TO postgres;
            ALTER ROLE "$DB_USER" CREATEDB;
            GRANT ALL PRIVILEGES ON DATABASE postgres TO "$DB_USER";
            EOF

            echo "Creating Database $DB_NAME if not exists..."
            if ! psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
              echo "Database does not exist. Creating..."
              # Create database with owner set to DB_USER
              psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"
            else
              echo "Database $DB_NAME already exists. Updating owner..."
              psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"
            fi

            echo "Granting privileges..."
            export PGPASSWORD=$ROOT_PASSWORD
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

            echo "Granting schema permissions..."
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
      path                  = "/_health"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
  }
}

output "strapi_module" {
  description = "strapi application module configuration"
  value       = local.strapi_module
}
