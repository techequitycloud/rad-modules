# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0
#
# Updated: January 2025
# Reason: Bitnami Moodle deprecated on August 28, 2025
# Alternative: Using lthub/moodle (7M+ pulls, actively maintained)
# Database: PostgreSQL (instead of MySQL)

locals {
  moodle_module = {
    app_name        = "moodle"
    description     = "Moodle LMS - Online learning and course management platform"
    
    # ✅ Updated to use working alternative (lthub/moodle)
    # Bitnami Moodle was moved to bitnamilegacy with no future updates
    container_image = "lthub/moodle:latest"
    image_source    = "prebuilt"
    
    # ✅ Updated port - lthub/moodle uses standard HTTP port 80
    container_port  = 80
    
    # ✅ Changed from MYSQL_8_0 to POSTGRES_15
    database_type   = "POSTGRES_15"
    db_name         = "moodle"
    db_user         = "moodle"

    # Cloud SQL configuration
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/postgresql"

    # NFS Configuration
    nfs_enabled    = true
    nfs_mount_path = "/mnt"

    # GCS Volumes
    # Note: The bucket name will be resolved by main.tf using the name "moodle-data"
    gcs_volumes = [{
      name       = "moodle-data"
      # ✅ Updated mount path for lthub/moodle
      mount_path = "/var/moodledata"
      read_only  = false
    }]

    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "2Gi"
    }
    min_instance_count = 0
    max_instance_count = 3

    # ✅ Updated environment variables for PostgreSQL
    environment_variables = {
      # Database configuration (PostgreSQL)
      MOODLE_DB_TYPE = "pgsql"
      MOODLE_DB_PORT = "5432"
      
      # Site configuration
      MOODLE_SITE_NAME     = "Moodle LMS"
      MOODLE_SITE_FULLNAME = "Moodle Learning Management System"
      MOODLE_ADMIN_USER    = "admin"
      MOODLE_ADMIN_EMAIL   = "admin@example.com"
      
      # Installation settings
      MOODLE_SKIP_INSTALL = "no"
      MOODLE_UPDATE       = "yes"
    }

    # ✅ Changed from MySQL plugins to PostgreSQL extensions
    enable_postgres_extensions = true
    postgres_extensions        = [
      "pg_stat_statements",
      "pg_trgm"
    ]

    # ✅ Removed MySQL-specific settings
    enable_mysql_plugins = false
    mysql_plugins        = []

    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Moodle Database and User in PostgreSQL"
        # ✅ Using PostgreSQL client image
        image           = "postgres:15-alpine"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache netcat-openbsd

            # Use DB_IP if available, else DB_HOST.
            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            # ✅ Wait for PostgreSQL port 5432 (instead of MySQL 3306)
            echo "Waiting for PostgreSQL database..."
            until nc -z $TARGET_DB_HOST 5432; do
              echo "Waiting for PostgreSQL port 5432..."
              sleep 2
            done

            # ✅ PostgreSQL connection configuration
            export PGHOST="$TARGET_DB_HOST"
            export PGPORT="5432"
            export PGUSER="postgres"
            export PGPASSWORD="$ROOT_PASSWORD"

            echo "Creating User $DB_USER if not exists..."
            # ✅ PostgreSQL user creation syntax
            psql -v ON_ERROR_STOP=1 <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '$DB_USER') THEN
    CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
  ELSE
    ALTER USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
  END IF;
END
\$\$;
EOF

            echo "Creating Database $DB_NAME if not exists..."
            # ✅ PostgreSQL database creation with UTF8 encoding
            psql -v ON_ERROR_STOP=1 <<EOF
SELECT 'CREATE DATABASE $DB_NAME OWNER $DB_USER ENCODING ''UTF8'' LC_COLLATE ''en_US.UTF-8'' LC_CTYPE ''en_US.UTF-8'' TEMPLATE template0'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec
EOF

            echo "Granting privileges..."
            # ✅ PostgreSQL privilege grants
            psql -v ON_ERROR_STOP=1 <<EOF
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

            # ✅ Connect to the new database and grant schema privileges
            export PGDATABASE="$DB_NAME"
            psql -v ON_ERROR_STOP=1 <<EOF
GRANT ALL ON SCHEMA public TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO $DB_USER;
EOF

            echo "PostgreSQL DB Init complete."
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
      }
    ]

    # ✅ Updated startup probe for lthub/moodle (needs more time to initialize)
    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 180  # Increased for Moodle initialization
      timeout_seconds       = 10
      period_seconds        = 30
      failure_threshold     = 10
    }
    
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 120
      timeout_seconds       = 5
      period_seconds        = 60
      failure_threshold     = 3
    }
  }
}

output "moodle_module" {
  description = "moodle application module configuration"
  value       = local.moodle_module
}
