# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  django_module = {
    app_name        = "django"
    description     = "Django Web Application - High-level Python web framework"
    container_image = "python:3.11-slim" # Placeholder, image built via custom build
    app_version     = "latest"

    # image_source    = "prebuilt"

    # Custom build configuration
    image_source    = "custom"
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "django"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = "cloudrunapp-repo"
    }

    container_port  = 8080
    database_type   = "POSTGRES_15"
    db_name         = "django"
    db_user         = "django"
    db_tier         = "db-f1-micro"
    enable_image_mirroring     = true
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    gcs_volumes = [
      {
        name       = "django-media"
        mount_path = "/app/media"
        read_only  = false
        mount_options = [
          "implicit-dirs",
          "metadata-cache-ttl-secs=60",
          "uid=1000",
          "gid=1000",
          "dir-mode=777",
          "file-mode=666"
        ]
      }
    ]

    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "1Gi"
    }
    min_instance_count = 0
    max_instance_count = 3

    environment_variables = {
      DJANGO_SETTINGS_MODULE    = "myproject.settings"
      APPLICATION_SETTINGS      = ""
      DEBUG                     = "False"
      ALLOWED_HOSTS             = "*"
      DB_ENGINE                 = "django.db.backends.postgresql"
      DB_PORT                   = "5432"
      STATIC_ROOT               = "/app/static"
      MEDIA_ROOT                = "/app/media"
      DJANGO_SUPERUSER_EMAIL    = "admin@example.com"
      DJANGO_SUPERUSER_USERNAME = "admin"
    }

    enable_postgres_extensions = true
    postgres_extensions         = ["pg_trgm", "unaccent", "hstore", "citext"]

    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Django Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache postgresql-client

            # Use DB_IP if available (injected by CloudRunApp), else DB_HOST
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
            GRANT "$DB_USER" TO postgres;
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

            echo "Granting schema privileges (PG15+)..."
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" <<EOF
            GRANT ALL ON SCHEMA public TO "$DB_USER";
            GRANT ALL ON ALL TABLES IN SCHEMA public TO "$DB_USER";
            GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO "$DB_USER";
            GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO "$DB_USER";
            ALTER DATABASE "$DB_NAME" OWNER TO "$DB_USER";
            EOF

            echo "DB Init complete."
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
      },
      {
        name            = "migrate"
        description     = "Run Django Migrations"
        image           = null
        command         = ["/bin/sh", "-c"]
        args            = ["if [ -f manage.py ]; then python manage.py migrate; else echo 'manage.py not found, skipping migration'; fi"]
        mount_nfs       = false
        mount_gcs_volumes = ["django-media"]
        execute_on_apply = true
      }
    ]

    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 90
      timeout_seconds       = 5
      period_seconds        = 10
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
  }
}

output "django_module" {
  description = "django application module configuration"
  value       = local.django_module
}
