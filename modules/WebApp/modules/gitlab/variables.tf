# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

#########################################################################
# GitLab CE Preset Configuration
#########################################################################

locals {
  gitlab_module = {
    app_name        = "gitlab"
    description     = "GitLab DevOps Platform - Complete DevOps platform"
    # Use specific version for stability
    container_image = "gitlab/gitlab-ce:16.8.1-ce.0"
    image_source    = "prebuilt"
    container_port  = 80
    database_type   = "POSTGRES_15"
    db_name         = "gitlabhq_production"
    db_user         = "gitlab"

    # We use external DB, but GitLab needs TCP connection.
    # Cloud Run volume mount for socket is optional if we use TCP (IP).
    # But sticking to default pattern.
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/postgresql"

    # Storage volumes
    # GitLab needs persistent storage for:
    # - /var/opt/gitlab (Data: Git repos, Redis dumps, etc.)
    # - /etc/gitlab (Config: gitlab.rb, secrets.json)
    # - /var/log/gitlab (Logs: optional but good)
    gcs_volumes = [
      {
        name          = "gitlab-data"
        bucket_name   = null # Auto-generated based on suffix
        mount_path    = "/var/opt/gitlab"
        read_only     = false
        mount_options = ["implicit-dirs", "uid=998", "gid=998", "file-mode=660", "dir-mode=770", "metadata-cache-ttl-secs=60"]
      },
      {
        name          = "gitlab-config"
        bucket_name   = null # Auto-generated based on suffix
        mount_path    = "/etc/gitlab"
        read_only     = false
        mount_options = ["implicit-dirs", "uid=998", "gid=998", "file-mode=600", "dir-mode=700", "metadata-cache-ttl-secs=60"]
      }
    ]

    # Resource limits - GitLab is heavy
    container_resources = {
      cpu_limit    = "4000m"
      memory_limit = "8Gi"
    }

    # Internal Redis/Gitaly requires single instance for consistency
    min_instance_count = 1
    max_instance_count = 1

    # Environment variables
    environment_variables = {
      # Redirect logs to stdout for Cloud Logging
      GITLAB_OMNIBUS_CONFIG = <<-EOT
        external_url 'https://gitlab.example.com';
        postgresql['enable'] = false;
        gitlab_rails['db_adapter'] = 'postgresql';
        gitlab_rails['db_encoding'] = 'utf8';
        gitlab_rails['db_host'] = ENV['DB_HOST'];
        gitlab_rails['db_port'] = 5432;
        gitlab_rails['db_database'] = ENV['DB_NAME'];
        gitlab_rails['db_username'] = ENV['DB_USER'];
        gitlab_rails['db_password'] = ENV['DB_PASSWORD'];

        # Redis (Internal for now)
        redis['enable'] = true;

        # Disable bundled services to save resources
        prometheus['enable'] = false;
        grafana['enable'] = false;
        gitlab_kas['enable'] = false;
        mattermost['enable'] = false;
        registry['enable'] = false;

        # Nginx configuration
        nginx['listen_port'] = 80;
        nginx['listen_https'] = false;
        nginx['proxy_set_headers'] = {
          "X-Forwarded-Proto" => "https",
          "X-Forwarded-Ssl" => "on"
        };
      EOT
    }

    # Initialization Jobs
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create GitLab Database, User and Extensions"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache postgresql-client

            echo "Waiting for database..."
            export PGPASSWORD=$ROOT_PASSWORD
            # DB_HOST provided by WebApp (IP address)
            until psql -h $DB_HOST -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; do
              echo "Waiting for database connection at $DB_HOST..."
              sleep 2
            done

            echo "Creating Role $DB_USER if not exists..."
            psql -h $DB_HOST -p 5432 -U postgres -d postgres <<EOF
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
            if ! psql -h $DB_HOST -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
              echo "Database does not exist. Creating as $DB_USER..."
              export PGPASSWORD=$DB_PASSWORD
              psql -h $DB_HOST -p 5432 -U $DB_USER -d postgres -c "CREATE DATABASE \"$DB_NAME\";"
            else
              echo "Database $DB_NAME already exists."
            fi

            echo "Installing Extensions..."
            export PGPASSWORD=$ROOT_PASSWORD
            psql -h $DB_HOST -p 5432 -U postgres -d $DB_NAME <<EOF
            CREATE EXTENSION IF NOT EXISTS pg_trgm;
            CREATE EXTENSION IF NOT EXISTS btree_gist;
            EOF

            echo "Granting privileges..."
            psql -h $DB_HOST -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

            echo "DB Init complete."
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
      }
    ]

    # Handle extensions in init job to avoid dependency loop
    enable_postgres_extensions = false
    postgres_extensions         = [] # Handled in db-init

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
