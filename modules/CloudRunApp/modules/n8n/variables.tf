# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  n8n_module = {
    app_name        = "n8n"
    description     = "n8n Workflow Automation - Workflow automation platform"
    container_image = "n8nio/n8n"
    application_version = "2.4.6"
    image_source    = "custom"
    enable_image_mirroring = true
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "n8n"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = null
    }
    container_port  = 5678
    database_type   = "POSTGRES_15"
    db_name         = "n8n_db"
    db_user         = "n8n_user"
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"
    gcs_volumes = [{
      name       = "n8n-data"
      mount_path = "/home/node/.n8n"
      read_only  = false
      mount_options = [
        "implicit-dirs",
        "metadata-cache-ttl-secs=60",
        "uid=1000",
        "gid=1000"
      ]
    }]
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 0
    max_instance_count = 3
    environment_variables = {
      DB_TYPE                          = "postgresdb"
      DB_POSTGRESDB_PORT               = "5432"
      N8N_USER_MANAGEMENT_DISABLED     = "false"
      EXECUTIONS_DATA_SAVE_ON_ERROR    = "all"
      EXECUTIONS_DATA_SAVE_ON_SUCCESS  = "all"
      GENERIC_TIMEZONE                 = "UTC"
      TZ                               = "UTC"
      N8N_DEFAULT_BINARY_DATA_MODE     = "filesystem"
      N8N_EMAIL_MODE                   = "smtp"
      N8N_SMTP_HOST                    = ""
      N8N_SMTP_PORT                    = "587"
      N8N_SMTP_USER                    = ""
      N8N_SMTP_SENDER                  = ""
      N8N_SMTP_SSL                     = "false"
    }
    enable_postgres_extensions = false
    postgres_extensions         = []

    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create N8N Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache postgresql-client

            # Use DB_IP if available, else DB_HOST, else DB_POSTGRESDB_HOST (for n8n)
            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            TARGET_DB_HOST="$${TARGET_DB_HOST:-$${DB_POSTGRESDB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            echo "Waiting for PostgreSQL..."
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
      path                  = "/"
      initial_delay_seconds = 120
      timeout_seconds       = 3
      period_seconds        = 10
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 30
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
  }
}

output "n8n_module" {
  description = "n8n application module configuration"
  value       = local.n8n_module
}
