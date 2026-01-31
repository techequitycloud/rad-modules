locals {
  medusa_module = {
    app_name            = "medusa"
    application_version = var.application_version
    display_name        = "Medusa Ecommerce"
    description         = "Medusa - Building blocks for digital commerce"

    # Medusa requires a custom built image with the storefront/backend code.
    # We provide a placeholder, but users should override this.
    container_image = ""
    image_source    = "custom"

    # Support for prebuilt image mirroring
    enable_image_mirroring = false

    # Enable custom build from scripts/medusa
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "medusa"
      dockerfile_content = null
      build_args = {
        APP_VERSION = var.application_version
      }
      artifact_repo_name = null
    }

    container_port = 9000
    database_type  = "POSTGRES_15"
    db_name        = "medusa_db"
    db_user        = "medusa_user"

    # Enable NFS for Redis
    nfs_enabled    = true
    nfs_mount_path = "/mnt/nfs"

    # enable_cloudsql_volume     = true   # Disabled to use IP based connection
    enable_cloudsql_volume     = false
    cloudsql_volume_mount_path = "/cloudsql"

    # Storage volumes
    # Medusa supports S3/GCS plugins for file storage.
    # We provision a bucket which can be used by the plugin.
    # We also provide a local volume if needed, though ephemeral in Cloud Run without GCS Fuse.
    gcs_volumes = [
      {
        name          = "medusa-uploads"
        bucket_name   = null # Auto-generated based on suffix
        mount_path    = "/app/medusa/uploads"
        read_only     = false
        mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60", "uid=1000", "gid=1000", "file-mode=777", "dir-mode=777"]
      }
    ]

    # Resource limits
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "2Gi"
    }
    min_instance_count = 0
    max_instance_count = 3

    # Environment variables
    environment_variables = {
      NODE_ENV = "production"
      # DB connection details will be injected by main.tf
    }

    # Initialization Jobs
    initialization_jobs = [
      {
        name        = "db-init"
        description = "Create Medusa Database and User"
        image       = "alpine:3.19"
        command     = ["/bin/sh", "-c"]
        args = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache postgresql-client

            # Use DB_HOST which is configured to be socket or IP
            TARGET_DB_HOST="$${DB_HOST}"
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
      },
      {
        name        = "medusa-migrations"
        description = "Run Medusa Migrations"
        image       = null # Use the application image
        command     = ["/bin/sh", "-c"]
        args = [
          <<-EOT
            set -e
            echo "Running Medusa migrations..."
            npx medusa migrations run
            echo "Migrations complete."
          EOT
        ]
        mount_nfs         = true
        mount_gcs_volumes = []
        execute_on_apply  = true
      }
    ]

    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/health"
      initial_delay_seconds = 120
      timeout_seconds       = 10
      period_seconds        = 15
      failure_threshold     = 12
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/health"
      initial_delay_seconds = 120
      timeout_seconds       = 10
      period_seconds        = 30
      failure_threshold     = 3
    }
  }

  application_modules = {
    medusa = local.medusa_module
  }

  module_env_vars = {
    DB_HOST                   = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    DB_PORT                   = "5432"
    DB_NAME                   = local.database_name_full
    DB_USER                   = local.database_user_full
    REDIS_URL                 = ""
    MEDUSA_FILE_GOOGLE_BUCKET = ""        # Disable GCS plugin; use Fuse mount at /app/medusa/uploads
    HOST                      = "0.0.0.0" # Ensure binding to all interfaces
  }

  module_secret_env_vars = {
    DB_PASSWORD   = try(google_secret_manager_secret.db_password[0].secret_id, "")
    JWT_SECRET    = try(google_secret_manager_secret.medusa_jwt_secret.secret_id, "")
    COOKIE_SECRET = try(google_secret_manager_secret.medusa_cookie_secret.secret_id, "")
  }

  module_storage_buckets = [
    {
      name_suffix              = "medusa-uploads"
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
# MEDUSA SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "medusa_jwt_secret" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "medusa_jwt_secret" {
  secret_id = "${local.wrapper_prefix}-jwt-secret"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "medusa_jwt_secret" {
  secret      = google_secret_manager_secret.medusa_jwt_secret.id
  secret_data = random_password.medusa_jwt_secret.result
}

resource "random_password" "medusa_cookie_secret" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "medusa_cookie_secret" {
  secret_id = "${local.wrapper_prefix}-cookie-secret"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "medusa_cookie_secret" {
  secret      = google_secret_manager_secret.medusa_cookie_secret.id
  secret_data = random_password.medusa_cookie_secret.result
}
