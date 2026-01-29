locals {
  directus_module = {
    app_name            = "directus"
    description         = "Directus - Open Source Headless CMS and Backend-as-a-Service"
    application_version = "11.1.0"
    container_image     = "directus/directus"
    container_port      = 8055
    database_type       = "POSTGRES_15"
    db_name             = "directus"
    db_user             = "directus"

    # Custom build configuration
    image_source = "custom"
    enable_image_mirroring = false
    
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "directus"
      dockerfile_content = null
      build_args = {
        DIRECTUS_VERSION = "11.1.0"
      }
      artifact_repo_name = null
    }

    # Performance optimization
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    # NFS Configuration (for Redis/cache)
    nfs_enabled    = true
    nfs_mount_path = "/mnt/nfs"

    # GCS volumes for uploads
    gcs_volumes = [
      {
        name          = "directus-uploads"
        bucket_name   = null  # Will be auto-generated
        mount_path    = "/directus/uploads"
        read_only     = false
        readonly      = false
        mount_options = [
          "implicit-dirs",
          "file-mode=777",
          "dir-mode=777",
          "uid=1000",      # node user UID
          "gid=1000"       # node group GID
        ]
      }
    ]

    # Resource limits
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "2Gi"
    }
    min_instance_count = 0
    max_instance_count = 5

    # Container command and args
    container_command = null
    container_args    = null

    # Environment variables
    environment_variables = {
      # CORS configuration
      CORS_ENABLED = "true"
      CORS_ORIGIN  = "true"

      # Server configuration
      PUBLIC_URL = "https://your-directus-url.run.app"

      # Cache configuration
      CACHE_ENABLED = "false"

      # Rate limiting
      RATE_LIMITER_ENABLED  = "false"
      RATE_LIMITER_POINTS   = "50"
      RATE_LIMITER_DURATION = "1"

      # Storage configuration - Use LOCAL with GCS Fuse mount
      STORAGE_LOCATIONS = "local"
      STORAGE_LOCAL_ROOT = "/directus/uploads"

      # Email configuration (optional)
      EMAIL_FROM = "noreply@your-domain.com"
      EMAIL_TRANSPORT = "smtp"

      # Logging
      LOG_LEVEL = "info"
      LOG_STYLE = "pretty"

      # Assets
      ASSETS_CACHE_TTL = "30m"
      ASSETS_TRANSFORM_MAX_CONCURRENT = "4"

      # Database Client (Static)
      DB_CLIENT = "pg"
      DB_PORT   = "5432"

      # Websockets
      WEBSOCKETS_ENABLED = "true"
    }

    # Initialization Jobs
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Directus Database and User"
        image           = "postgres:15-alpine"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache postgresql-client

            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            echo "Waiting for database..."
            export PGPASSWORD="$ROOT_PASSWORD"
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
            GRANT "$DB_USER" TO postgres;
            GRANT ALL PRIVILEGES ON DATABASE postgres TO "$DB_USER";
            EOF

            echo "Creating Database $DB_NAME if not exists..."
            if ! psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
              echo "Database does not exist. Creating as $DB_USER..."
              psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"
            else
              echo "Database $DB_NAME already exists."
              psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"
            fi

            echo "Granting privileges..."
            export PGPASSWORD="$ROOT_PASSWORD"
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

            echo "Granting schema permissions (PG15+)..."
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";"

            echo "Installing extensions..."
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS \"postgis\";" || echo "PostGIS extension not available, skipping..."

            echo "DB Init complete."
          EOT
        ]
        cpu_limit         = "1000m"
        memory_limit      = "512Mi"
        timeout_seconds   = 600
        max_retries       = 3
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
        depends_on_jobs   = []
      },
      {
        name            = "directus-bootstrap"
        description     = "Bootstrap Directus (run migrations)"
        image           = null
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Waiting for database to be ready..."
            sleep 10

            echo "Bootstrapping Directus..."
            npx directus bootstrap

            echo "Bootstrap complete."
          EOT
        ]
        cpu_limit         = "2000m"
        memory_limit      = "2Gi"
        timeout_seconds   = 900
        max_retries       = 2
        mount_nfs         = false
        mount_gcs_volumes = ["directus-uploads"]
        execute_on_apply  = true
        depends_on_jobs   = ["db-init"]
      }
    ]

    # PostgreSQL extensions
    enable_postgres_extensions = true
    postgres_extensions        = ["uuid-ossp"]

    # Health checks
    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/server/health"
      initial_delay_seconds = 0
      timeout_seconds       = 10
      period_seconds        = 30
      failure_threshold     = 10
    }

    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/server/health"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
  }

  application_modules = {
    directus = local.directus_module
  }

  module_env_vars = {
    DB_HOST                = local.db_internal_ip
    DB_DATABASE            = local.database_name_full
    DB_USER                = local.database_user_full
    PUBLIC_URL             = local.predicted_service_url
    ADMIN_EMAIL            = try(local.final_environment_variables["ADMIN_EMAIL"], "admin@example.com")
  }

  module_secret_env_vars = {
    KEY            = try(google_secret_manager_secret.directus_key.secret_id, "")
    SECRET         = try(google_secret_manager_secret.directus_secret.secret_id, "")
    ADMIN_PASSWORD = try(google_secret_manager_secret.directus_admin_password.secret_id, "")
    DB_PASSWORD    = try(google_secret_manager_secret.db_password[0].secret_id, "")
  }

  module_storage_buckets = [
    {
      name_suffix              = "directus-uploads"
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
# DIRECTUS SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "directus_key" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "directus_key" {
  secret_id = "${local.wrapper_prefix}-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "directus_key" {
  secret      = google_secret_manager_secret.directus_key.id
  secret_data = random_password.directus_key.result
}

resource "random_password" "directus_secret" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "directus_secret" {
  secret_id = "${local.wrapper_prefix}-secret-app"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "directus_secret" {
  secret      = google_secret_manager_secret.directus_secret.id
  secret_data = random_password.directus_secret.result
}

resource "random_password" "directus_admin_password" {
  length  = 20
  special = false
}

resource "google_secret_manager_secret" "directus_admin_password" {
  secret_id = "${local.wrapper_prefix}-admin-password"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "directus_admin_password" {
  secret      = google_secret_manager_secret.directus_admin_password.id
  secret_data = random_password.directus_admin_password.result
}

# ==============================================================================
# STATE MIGRATION
# ==============================================================================

moved {
  from = random_password.directus_key[0]
  to   = random_password.directus_key
}

moved {
  from = google_secret_manager_secret.directus_key[0]
  to   = google_secret_manager_secret.directus_key
}

moved {
  from = google_secret_manager_secret_version.directus_key[0]
  to   = google_secret_manager_secret_version.directus_key
}

moved {
  from = random_password.directus_secret[0]
  to   = random_password.directus_secret
}

moved {
  from = google_secret_manager_secret.directus_secret[0]
  to   = google_secret_manager_secret.directus_secret
}

moved {
  from = google_secret_manager_secret_version.directus_secret[0]
  to   = google_secret_manager_secret_version.directus_secret
}

moved {
  from = random_password.directus_admin_password[0]
  to   = random_password.directus_admin_password
}

moved {
  from = google_secret_manager_secret.directus_admin_password[0]
  to   = google_secret_manager_secret.directus_admin_password
}

moved {
  from = google_secret_manager_secret_version.directus_admin_password[0]
  to   = google_secret_manager_secret_version.directus_admin_password
}
