locals {
  cyclos_module = {
    app_name            = "cyclos"
    application_version = var.application_version
    display_name        = "Cyclos Community Edition"
    description         = "Cyclos Banking System on Cloud Run"
    container_image     = "cyclos/cyclos"

    # image_source    = "build"
    image_source    = "prebuilt"
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "."
      dockerfile_content = null
      build_args         = {
        APP_VERSION = var.application_version
      }
      artifact_repo_name = null
    }
    container_port  = 8080
    database_type   = "POSTGRES_15"
    db_name         = "cyclos"
    db_user         = "cyclos"
    # Cyclos uses PGSimpleDataSource with TCP connection (via private IP)
    # Cloud SQL sidecar is not needed when using VPC connector
    enable_cloudsql_volume     = false
    cloudsql_volume_mount_path = "/cloudsql"
    gcs_volumes = []

    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }

    min_instance_count = 1
    max_instance_count = 1

    environment_variables = {
      DB_HOST                             = "/var/run/postgresql"
      DB_PORT                             = "5432"
      CYCLOS_HOME                         = "/usr/local/cyclos"
      "cyclos.storedFileContentManager"            = "gcs"
      "cyclos.storedFileContentManager.bucketName" = "${var.tenant_deployment_id}-cyclos-storage"
    }

    # ✅ Enable PostgreSQL extensions
    enable_postgres_extensions = true
    postgres_extensions = [
      "pg_trgm",
      "uuid-ossp",
      "cube",           # Required by earthdistance
      "earthdistance",
      "postgis",
      "unaccent"
    ]

    initialization_jobs = [
      # ===================================================================
      # JOB 1: Create PostgreSQL Extensions (as postgres/root user)
      # ===================================================================
      {
        name            = "create-extensions"
        description     = "Create required PostgreSQL extensions"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "=== PostgreSQL Extension Setup ==="

            # Install PostgreSQL client
            apk update && apk add --no-cache postgresql-client

            # Use DB_IP if available (injected by CloudRunApp), else DB_HOST
            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            # Wait for database
            echo "Waiting for PostgreSQL..."
            export PGPASSWORD=$ROOT_PASSWORD
            until psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; do
              echo "Waiting for database connection..."
              sleep 2
            done
            echo "✓ Database is ready"

            # Create database if it doesn't exist (as postgres user)
            echo "Creating database $DB_NAME if not exists..."
            if ! psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
              echo "Creating database..."
              psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "CREATE DATABASE \"$DB_NAME\";"
              echo "✓ Database created"
            else
              echo "✓ Database already exists"
            fi

            # Create extensions (as postgres user - has cloudsqlsuperuser role)
            echo "Creating PostgreSQL extensions..."
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" <<EOF
            -- Create extensions in order (dependencies first)
            CREATE EXTENSION IF NOT EXISTS pg_trgm;
            CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
            CREATE EXTENSION IF NOT EXISTS cube;           -- Required by earthdistance
            CREATE EXTENSION IF NOT EXISTS earthdistance;  -- Depends on cube
            CREATE EXTENSION IF NOT EXISTS postgis;
            CREATE EXTENSION IF NOT EXISTS unaccent;

            -- Verify extensions
            SELECT extname, extversion FROM pg_extension ORDER BY extname;
            EOF

            echo "✓ Extensions created successfully"
            echo "=== Extension Setup Complete ==="
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
        cpu_limit         = "1000m"
        memory_limit      = "512Mi"
        timeout_seconds   = 300
        max_retries       = 2
      },

      # ===================================================================
      # JOB 2: Create Cyclos User and Grant Permissions
      # ===================================================================
      {
        name            = "create-user"
        description     = "Create Cyclos database user and grant permissions"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "=== Cyclos User Setup ==="

            # Install PostgreSQL client
            apk update && apk add --no-cache postgresql-client

            # Use DB_IP if available
            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            # Wait for database
            export PGPASSWORD=$ROOT_PASSWORD
            until psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; do
              echo "Waiting for database..."
              sleep 2
            done

            # Create Cyclos user
            echo "Creating user $DB_USER..."
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres <<EOF
            DO \$\$
            BEGIN
              IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
                CREATE ROLE "$DB_USER" WITH LOGIN PASSWORD '$DB_PASSWORD';
                RAISE NOTICE 'User created';
              ELSE
                ALTER ROLE "$DB_USER" WITH PASSWORD '$DB_PASSWORD';
                RAISE NOTICE 'User password updated';
              END IF;
            END
            \$\$;

            -- Grant necessary privileges
            ALTER ROLE "$DB_USER" CREATEDB;
            ALTER ROLE "$DB_USER" INHERIT;
            GRANT ALL PRIVILEGES ON DATABASE "$DB_NAME" TO "$DB_USER";
            GRANT "$DB_USER" TO postgres;
            EOF

            # Grant schema and extension privileges
            echo "Granting schema privileges..."
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" <<EOF
            GRANT ALL ON SCHEMA public TO "$DB_USER";
            GRANT ALL ON ALL TABLES IN SCHEMA public TO "$DB_USER";
            GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO "$DB_USER";
            GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO "$DB_USER";

            -- Grant usage on extensions
            GRANT USAGE ON SCHEMA public TO "$DB_USER";

            -- Set default privileges for future objects
            ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "$DB_USER";
            ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "$DB_USER";
            ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO "$DB_USER";
            EOF

            # Change database owner to cyclos user
            echo "Setting database owner..."
            psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"

            echo "✓ User setup complete"
            echo "=== User Setup Complete ==="
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
        cpu_limit         = "1000m"
        memory_limit      = "512Mi"
        timeout_seconds   = 300
        max_retries       = 2
      }
    ]

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 90  # Increased to allow schema creation
      timeout_seconds       = 30
      period_seconds        = 60
      failure_threshold     = 5   # Increased tolerance
    }

    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/api"
      initial_delay_seconds = 120  # Increased
      timeout_seconds       = 10
      period_seconds        = 60
      failure_threshold     = 3
    }
  }

  # Aggregate all modules into a single map for easy lookup
  application_modules = {
    cyclos = local.cyclos_module
  }

  # Cyclos uses PGSimpleDataSource with explicit portNumber=5432 in cyclos.properties
  # This requires TCP connection (IP address), not Unix sockets.
  # The Cloud SQL Auth Proxy sidecar is not needed when using private IP via VPC connector.
  module_env_vars = {
    DB_HOST = local.db_internal_ip
  }

  module_secret_env_vars = {}

  module_storage_buckets = [
    {
      name_suffix              = "cyclos-storage"
      location                 = var.deployment_region
      storage_class            = "STANDARD"
      force_destroy            = true
      versioning_enabled       = false
      public_access_prevention = "enforced"
    }
  ]
}
