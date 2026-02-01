# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0
#
# Updated: January 2025
# Reason: Implementing custom image build with PostgreSQL support and Wkhtmltopdf

locals {
  moodle_module = {
    app_name            = "moodle"
    description         = "Moodle LMS - Online learning and course management platform"
    application_version = var.application_version
    container_image     = "" # Empty for custom build

    # ✅ Use custom build
    image_source           = "custom"
    enable_image_mirroring = false

    # ✅ Custom build configuration
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "moodle"
      dockerfile_content = null
      build_args = {
        APP_VERSION = var.application_version
        TARGETARCH  = "amd64"
      }
      artifact_repo_name = null
    }

    # ✅ Standard HTTP port 8080 (Apache)
    container_port = 8080

    # ✅ PostgreSQL 15
    database_type = "POSTGRES_15"
    db_name       = "moodle"
    db_user       = "moodle"

    # ✅ Disable image mirroring (not needed for custom builds)
    enable_image_mirroring = false

    # Cloud SQL configuration
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    # NFS Configuration
    nfs_enabled    = true
    nfs_mount_path = "/mnt"

    # GCS Volumes - Mount path changed to avoid conflict with NFS /mnt
    gcs_volumes = [
      {
        name        = "moodle-data"
        bucket_name = null               # Auto-generated
        mount_path  = "/gcs/moodle-data" # Changed from /mnt/filedir
        read_only   = false
        readonly    = false
        mount_options = [
          "implicit-dirs",
          "metadata-cache-ttl-secs=60",
          "file-mode=770",
          "dir-mode=770",
          "uid=33", # www-data user
          "gid=33"  # www-data group
        ]
      }
    ]

    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 0
    max_instance_count = 5

    # Container command and args
    container_command = null # Use default from Dockerfile
    container_args    = null # Use default from Dockerfile

    # ✅ Environment variables
    environment_variables = {
      # Database configuration (main.tf will inject DB_HOST, DB_NAME, etc.)
      MOODLE_DB_TYPE = "pgsql"
      MOODLE_DB_PORT = "5432"

      # Reverse Proxy Support (CRITICAL for Cloud Run)
      MOODLE_REVERSE_PROXY = "true"
      ENABLE_REVERSE_PROXY = "TRUE"

      # Site configuration
      MOODLE_SITE_NAME     = "Moodle LMS"
      MOODLE_SITE_FULLNAME = "Moodle Learning Management System"
      MOODLE_LANGUAGE      = "en"

      # Admin configuration
      MOODLE_ADMIN_USER     = "admin"
      MOODLE_ADMIN_EMAIL    = "admin@example.com"
      MOODLE_ADMIN_FULLNAME = "Moodle Administrator"

      # Installation settings
      MOODLE_SKIP_INSTALL = "no"
      MOODLE_UPDATE       = "yes"

      # Data directory
      MOODLE_DATA_DIR = "/mnt"
      DATA_PATH       = "/mnt"

      # PHP Configuration
      PHP_MAX_INPUT_VARS      = "5000"
      PHP_MEMORY_LIMIT        = "512M"
      PHP_POST_MAX_SIZE       = "512M"
      PHP_UPLOAD_MAX_FILESIZE = "512M"

      # Apache Configuration
      APACHE_RUN_USER  = "www-data"
      APACHE_RUN_GROUP = "www-data"
      APACHE_LOG_DIR   = "/var/log/apache2"

      # Redis configuration (if using NFS with Redis)
      MOODLE_REDIS_HOST = "localhost"
      MOODLE_REDIS_PORT = "6379"

      # Cron configuration
      CRON_INTERVAL = "1"
    }

    # ✅ PostgreSQL extensions
    enable_postgres_extensions = true
    postgres_extensions        = ["pg_trgm"] # Useful for Moodle search

    # ✅ Initialization Jobs
    initialization_jobs = [
      {
        name        = "nfs-init"
        description = "Initialize NFS permissions for Moodle"
        image       = "alpine:3.19"
        command     = ["/bin/sh", "-c"]
        args = [
          <<-EOT
            set -e
            echo "Creating Moodle data directories..."
            mkdir -p /mnt/filedir /mnt/temp /mnt/cache /mnt/localcache

            echo "Setting permissions..."
            chown -R 33:33 /mnt
            chmod -R 2770 /mnt

            echo "NFS permissions initialized successfully"
            ls -la /mnt
          EOT
        ]
        cpu_limit         = "500m"
        memory_limit      = "256Mi"
        timeout_seconds   = 300
        max_retries       = 2
        mount_nfs         = true
        mount_gcs_volumes = []
        execute_on_apply  = true
        depends_on_jobs   = []
      },
      {
        name        = "db-init"
        description = "Create Moodle Database and User in PostgreSQL"
        image       = "postgres:15-alpine"
        command     = ["/bin/sh", "-c"]
        args = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk add --no-cache postgresql-client

            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            echo "Waiting for PostgreSQL..."
            export PGPASSWORD="$ROOT_PASSWORD"
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
              psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\" ENCODING 'UTF8' LC_COLLATE='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' TEMPLATE=template0;"
            else
              echo "Database $DB_NAME already exists."
              psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"
            fi

            echo "Granting privileges..."
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

            echo "Granting schema permissions..."
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";"

            echo "Installing extensions..."
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

            echo "PostgreSQL DB Init complete."
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
        name        = "moodle-install"
        description = "Install Moodle if not already installed"
        image       = null # Use application image
        command     = ["/bin/sh", "-c"]
        args = [
          <<-EOT
            set -e

            echo "Checking if Moodle is already installed..."
            if [ -f /mnt/moodledata_installed ]; then
              echo "Moodle already installed, skipping..."
              exit 0
            fi

            echo "Running Moodle CLI installation..."
            cd /var/www/html

            # Wait for database to be ready
            sleep 10

            # Run Moodle installation
            sudo -u www-data php admin/cli/install_database.php \
              --lang=en \
              --adminuser="$${MOODLE_ADMIN_USER:-admin}" \
              --adminpass="$${MOODLE_ADMIN_PASSWORD:-Admin123!}" \
              --adminemail="$${MOODLE_ADMIN_EMAIL:-admin@example.com}" \
              --fullname="$${MOODLE_SITE_FULLNAME:-Moodle LMS}" \
              --shortname="$${MOODLE_SITE_NAME:-Moodle}" \
              --agree-license || echo "Installation may have already been completed"

            # Mark as installed
            touch /mnt/moodledata_installed

            echo "Moodle installation complete."
          EOT
        ]
        cpu_limit         = "2000m"
        memory_limit      = "4Gi"
        timeout_seconds   = 1800
        max_retries       = 1
        mount_nfs         = true
        mount_gcs_volumes = ["moodle-data"]
        execute_on_apply  = false # Run manually after deployment
        depends_on_jobs   = ["db-init", "nfs-init"]
      }
    ]

    # ✅ Health checks
    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 0
      timeout_seconds       = 10
      period_seconds        = 30
      failure_threshold     = 20 # Moodle takes time to start
    }

    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 120
      timeout_seconds       = 10
      period_seconds        = 60
      failure_threshold     = 3
    }
  }

  application_modules = {
    moodle = local.moodle_module
  }

  module_env_vars = {
    # Database connection (supports both MySQL and PostgreSQL)
    MOODLE_DB_HOST = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip

    # Force DB_HOST to use socket if enabled
    DB_HOST = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip

    MOODLE_DB_PORT = tostring(local.database_port)
    MOODLE_DB_USER = local.database_user_full
    MOODLE_DB_NAME = local.database_name_full

    # Database type: "pgsql" for PostgreSQL, "mysqli" for MySQL
    MOODLE_DB_TYPE = local.database_client_type == "POSTGRES" ? "pgsql" : "mysqli"

    # Redis Configuration
    MOODLE_REDIS_ENABLED  = tostring(var.redis_enabled)
    MOODLE_REDIS_HOST     = var.redis_enabled ? (var.redis_host == "localhost" && local.nfs_enabled ? local.nfs_internal_ip : var.redis_host) : ""
    MOODLE_REDIS_PORT     = var.redis_port
    MOODLE_REDIS_PASSWORD = var.redis_auth

    # SMTP Configuration
    MOODLE_SMTP_HOST   = ""
    MOODLE_SMTP_PORT   = "587"
    MOODLE_SMTP_USER   = ""
    MOODLE_SMTP_SECURE = "tls"
    MOODLE_SMTP_AUTH   = "LOGIN"

    # Pre-calculated Cloud Run URL (deterministic format)
    MOODLE_WWWROOT  = local.predicted_service_url
    MOODLE_SITE_URL = local.predicted_service_url
    MOODLE_URL      = local.predicted_service_url
    APP_URL         = local.predicted_service_url

    # Reverse Proxy Support (CRITICAL for Cloud Run)
    ENABLE_REVERSE_PROXY = "TRUE"
    MOODLE_REVERSE_PROXY = "true"

    # Cron Configuration (Managed by Cloud Scheduler)
    # CRON_INTERVAL = "1" # Deprecated

    # Site configuration
    MOODLE_SITE_NAME     = "Moodle LMS"
    MOODLE_SITE_FULLNAME = "Moodle Learning Management System"
    LANGUAGE             = "en"
    MOODLE_ADMIN_USER    = "admin"
    MOODLE_ADMIN_EMAIL   = "admin@example.com"

    # Installation settings
    MOODLE_SKIP_INSTALL = "no"
    MOODLE_UPDATE       = "yes"

    # Data directory
    MOODLE_DATA_DIR = "/mnt"
    DATA_PATH       = "/mnt"
  }

  module_secret_env_vars = {
    MOODLE_DB_PASSWORD   = try(google_secret_manager_secret.db_password[0].secret_id, "")
    MOODLE_CRON_PASSWORD = try(google_secret_manager_secret.moodle_cron_password[0].secret_id, "")
    MOODLE_SMTP_PASSWORD = try(google_secret_manager_secret.moodle_smtp_password[0].secret_id, "")
  }

  module_storage_buckets = [
    {
      name_suffix              = "moodle-data"
      location                 = local.region
      storage_class            = "STANDARD"
      force_destroy            = true
      versioning_enabled       = false
      lifecycle_rules          = []
      public_access_prevention = "inherited"
    }
  ]
}

# ==============================================================================
# MOODLE SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "moodle_cron_password" {
  count   = 1
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "moodle_cron_password" {
  count     = 1
  secret_id = "${local.wrapper_prefix}-cron-password"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "moodle_cron_password" {
  count       = 1
  secret      = google_secret_manager_secret.moodle_cron_password[0].id
  secret_data = random_password.moodle_cron_password[0].result
}

resource "google_secret_manager_secret" "moodle_smtp_password" {
  count     = 1
  secret_id = "${local.wrapper_prefix}-smtp-password"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "random_password" "moodle_smtp_password" {
  count   = 1
  length  = 24
  special = false
}

resource "google_secret_manager_secret_version" "moodle_smtp_password" {
  count       = 1
  secret      = google_secret_manager_secret.moodle_smtp_password[0].id
  secret_data = random_password.moodle_smtp_password[0].result
}

resource "google_cloud_scheduler_job" "moodle_cron_job" {
  count            = 1
  name             = "${local.resource_prefix}-moodle-cron"
  description      = "Trigger Moodle Cron"
  schedule         = "* * * * *"
  time_zone        = "Etc/UTC"
  attempt_deadline = "320s"
  project          = var.existing_project_id
  region           = local.region

  http_target {
    http_method = "GET"
    uri         = "${local.predicted_service_url}/admin/cron.php?password=${random_password.moodle_cron_password[0].result}"
  }
}
