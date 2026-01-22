# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0
#
# Updated: January 2025
# Reason: Implementing custom image build with PostgreSQL support and Wkhtmltopdf
# Reference: Based on lessons from modules/Moodle and Odoo build process

locals {
  moodle_module = {
    app_name        = "moodle"
    description     = "Moodle LMS - Online learning and course management platform"
    
    # ✅ Updated to use custom image build
    container_image = "" # Will be populated by the build process
    image_source    = "custom"
    
    # ✅ Custom build configuration
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "moodle"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = "webapp-repo"
    }

    # ✅ Updated port - Standard HTTP port 80 (Apache in custom image)
    container_port  = 80
    
    # ✅ Switched to POSTGRES_15 as per requirement
    database_type   = "POSTGRES_15"
    db_name         = "moodle"
    db_user         = "moodle"

    # Cloud SQL configuration
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/postgresql" # Postgres socket path

    # NFS Configuration
    nfs_enabled    = true
    nfs_mount_path = "/mnt"

    # GCS Volumes
    gcs_volumes = [{
      name       = "moodle-data"
      mount_path = "/var/moodledata"
      read_only  = false
      mount_options = [
        "implicit-dirs", 
        "stat-cache-ttl=60s", 
        "type-cache-ttl=60s",
        "uid=33", # www-data user
        "gid=33"  # www-data group
      ]
    }]

    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 1
    max_instance_count = 3

    # ✅ Environment variables - URL will be added dynamically in main.tf
    environment_variables = {
      # Database configuration (Postgres) handled by main.tf (MOODLE_DB_TYPE=pgsql)
      
      # Reverse Proxy Support (CRITICAL for Cloud Run)
      ENABLE_REVERSE_PROXY = "TRUE"
      MOODLE_REVERSE_PROXY = "true"
      
      # Cron Configuration
      CRON_INTERVAL = "1"
      
      # Site configuration
      MOODLE_SITE_NAME     = "Moodle LMS"
      MOODLE_SITE_FULLNAME = "Moodle Learning Management System"
      LANGUAGE             = "en"
      
      # Admin configuration
      MOODLE_ADMIN_USER    = "admin"
      MOODLE_ADMIN_EMAIL   = "admin@example.com"
      
      # Installation settings
      MOODLE_SKIP_INSTALL = "no"
      MOODLE_UPDATE       = "yes"
      
      # Data directory
      MOODLE_DATA_DIR = "/var/moodledata"
      DATA_PATH       = "/var/moodledata"
    }

    # ✅ MySQL Plugins
    enable_mysql_plugins = false
    mysql_plugins        = []

    # ✅ Postgres extensions (if needed, but standard Moodle usually fine)
    enable_postgres_extensions = false
    postgres_extensions        = []

    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Moodle Database and User in PostgreSQL"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache postgresql-client

            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            # Wait for PostgreSQL
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

    # ✅ Startup probe
    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 180
      timeout_seconds       = 60
      period_seconds        = 120
      failure_threshold     = 3
    }
    
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 180
      timeout_seconds       = 10
      period_seconds        = 60
      failure_threshold     = 3
    }
  }
}

output "moodle_module" {
  description = "moodle application module configuration"
  value       = local.moodle_module
}
