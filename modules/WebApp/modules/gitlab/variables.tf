# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  gitlab_module = {
    app_name        = "gitlab"
    description     = "GitLab DevOps Platform - Complete DevOps platform"
    container_image = "gitlab/gitlab-ce:16.8.0-ce.0"
    image_source    = "prebuilt"
    container_port  = 80
    database_type   = "POSTGRES_15"
    db_name         = "gitlab_db"
    db_user         = "gitlab_user"

    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/postgresql"

    gcs_volumes = [
      {
        bucket     = "$${tenant_id}-gitlab-data"
        mount_path = "/var/opt/gitlab"
        read_only  = false
      },
      {
        bucket     = "$${tenant_id}-gitlab-config"
        mount_path = "/etc/gitlab"
        read_only  = false
      }
    ]
    container_resources = {
      cpu_limit    = "4000m"
      memory_limit = "8Gi"
    }
    min_instance_count = 1
    max_instance_count = 5
    environment_variables = {
      GITLAB_OMNIBUS_CONFIG = "external_url 'https://gitlab.example.com'"
    }
    enable_postgres_extensions = true
    postgres_extensions         = ["pg_trgm", "btree_gist"]

    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Database and User"
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
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 300
      timeout_seconds       = 60
      period_seconds        = 60
      failure_threshold     = 5
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/users/sign_in"
      initial_delay_seconds = 300
      timeout_seconds       = 10
      period_seconds        = 60
      failure_threshold     = 3
    }
  }
}

output "gitlab_module" {
  description = "gitlab application module configuration"
  value       = local.gitlab_module
}
