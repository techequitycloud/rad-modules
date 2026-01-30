locals {
  django_module = {
    app_name            = "django"
    description         = "Django Web Application - High-level Python web framework"
    container_image     = "" # Placeholder, image built via custom build
    application_version = var.application_version

    # image_source    = "prebuilt"
    image_source = "custom"
    enable_image_mirroring = false

    # Custom build configuration
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "django"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = null
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
          "uid=2000",
          "gid=2000",
          "dir-mode=755",
          "file-mode=644"
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
        args            = [
          <<-EOT
            if [ -z "$DATABASE_URL" ] && [ -n "$DB_USER" ] && [ -n "$DB_NAME" ]; then
              export DATABASE_URL="postgres://$DB_USER:$DB_PASSWORD@$DB_HOST:$${DB_PORT:-5432}/$DB_NAME"
            fi
            if [ -f manage.py ]; then
              python manage.py migrate
              python manage.py collectstatic --noinput --clear
            else
              echo 'manage.py not found, skipping migration'
            fi
          EOT
        ]
        mount_nfs       = false
        mount_gcs_volumes = ["django-media"]
        execute_on_apply = true
      }
    ]

    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/health/"
      initial_delay_seconds = 90
      timeout_seconds       = 5
      period_seconds        = 10
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/health/"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
  }

  application_modules = {
    django = local.django_module
  }

  module_env_vars = {
    CLOUDRUN_SERVICE_URLS = local.predicted_service_url
    GS_BUCKET_NAME        = "${local.wrapper_prefix}-django-media"
  }

  module_secret_env_vars = {
    DJANGO_SUPERUSER_PASSWORD = try(google_secret_manager_secret.db_password[0].secret_id, "")
    SECRET_KEY                = try(google_secret_manager_secret.django_secret_key.secret_id, "")
  }

  module_storage_buckets = [
    {
      name_suffix              = "django-media"
      location                 = var.deployment_region
      storage_class            = "STANDARD"
      force_destroy            = true
      versioning_enabled       = false
      lifecycle_rules          = []
      public_access_prevention = "inherited"
    }
  ]
}

# ==============================================================================
# DJANGO SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "django_secret_key" {
  length  = 50
  special = false
}

resource "google_secret_manager_secret" "django_secret_key" {
  secret_id = "${local.wrapper_prefix}-secret-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "django_secret_key" {
  secret      = google_secret_manager_secret.django_secret_key.id
  secret_data = random_password.django_secret_key.result
}
