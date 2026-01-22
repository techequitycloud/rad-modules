# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  n8n_module = {
    app_name        = "n8n"
    description     = "n8n Workflow Automation - Workflow automation platform"
    container_image = "n8nio/n8n:latest"
    application_version = "latest"
    image_source    = "prebuilt"
    container_port  = 5678
    database_type   = "POSTGRES_15"
    db_name         = "n8n_db"
    db_user         = "n8n_user"
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"
    gcs_volumes = [{
      bucket     = "$${tenant_id}-n8n-data"
      mount_path = "/home/node/.n8n"
      read_only  = false
    }]
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "2Gi"
    }
    min_instance_count = 1
    max_instance_count = 1
    environment_variables = {
      DB_TYPE                          = "postgresdb"
      DB_POSTGRESDB_PORT               = "5432"
      N8N_USER_MANAGEMENT_DISABLED     = "false"
      EXECUTIONS_DATA_SAVE_ON_ERROR    = "all"
      EXECUTIONS_DATA_SAVE_ON_SUCCESS  = "all"
      GENERIC_TIMEZONE                 = "America/New_York"
      TZ                               = "America/New_York"
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
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 10
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
