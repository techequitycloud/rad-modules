# Define REDIS_URL locally to avoid cycles and complex logic in the module map
locals {
  directus_module = {
    app_name            = "directus"
    description         = "Directus - Open Source Headless CMS and Backend-as-a-Service"
    application_version = "11.1.0"
    container_image     = ""
    container_port      = 8055
    database_type       = "POSTGRES_15"
    db_name             = "directus"
    db_user             = "directus"

    # Custom build configuration
    image_source           = "custom"
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
    gcs_volumes = []

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
      CACHE_ENABLED = tostring(var.redis_enabled)
      CACHE_STORE   = var.redis_enabled ? "redis" : "memory"
      # REDIS value is injected via module_env_vars to avoid cycle with nfs_enabled

      # Rate limiting
      RATE_LIMITER_ENABLED  = "false"
      RATE_LIMITER_POINTS   = "50"
      RATE_LIMITER_DURATION = "1"

      # Storage configuration - Use GCS native driver
      STORAGE_LOCATIONS  = "gcs"

      # Email configuration (optional)
      EMAIL_FROM = "noreply@your-domain.com"
      # Removing EMAIL_TRANSPORT to use default behavior (disabled/console depending on version)
      # to avoid "Illegal transport" errors.

      # Logging
      LOG_LEVEL = "info"
      LOG_STYLE = "pretty"

      # Assets
      ASSETS_CACHE_TTL                = "30m"
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
        name        = "db-init"
        description = "Create Directus Database and User"
        image       = "postgres:15-alpine"
        command     = ["/bin/sh", "-c"]
        args = [
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
        name        = "directus-bootstrap"
        description = "Bootstrap Directus (run migrations)"
        image       = null
        command     = ["/bin/sh", "-c"]
        args = [
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

  # Calculate Redis connection string
  # To avoid cycles:
  # 1. We assume NFS is enabled if we are using this module (directus_module sets nfs_enabled = true).
  # 2. We use local.nfs_internal_ip from nfs.tf.
  # If the cycle persists, it means module_env_vars depends on nfs_internal_ip,
  # which depends on nfs_enabled (from main.tf), which depends on directus_module (from this file).

  # To break the cycle, we can decouple nfs_enabled determination for the purpose of this calculation
  # or use a different source for the IP if possible.
  # However, here we can assume: if var.redis_host is set, we don't need NFS info.
  # If var.redis_host is NOT set, we try to use NFS.

  # The cycle is:
  # local.module_env_vars -> local.redis_connection_string -> local.nfs_internal_ip -> local.nfs_enabled -> local.directus_module -> local.module_env_vars

  # We CANNOT reference local.nfs_internal_ip inside local.directus_module or anything that feeds back into it
  # (like module_env_vars which is referenced in main.tf).

  # Wait, module_env_vars IS part of the output of directus.tf that main.tf uses.
  # So we cannot use local.nfs_internal_ip here if nfs.tf depends on the output of this file.

  # Strategy:
  # Pass the logic to the shell/runtime via script? No, environment variables are terraform-time.
  # Use a separate local for the final environment variables that is NOT part of the module definition map?
  # But main.tf expects module_env_vars to be defined.

  # The issue is specifically that main.tf determines `local.final_nfs_enabled` based on `local.selected_module.nfs_enabled`.
  # And `nfs.tf` uses `local.final_nfs_enabled`.

  # If we remove `REDIS` from `module_env_vars` here and instead inject it in `main.tf` using a merge,
  # we can break the cycle because `main.tf` can access `local.nfs_internal_ip` AFTER it has determined `local.final_nfs_enabled`.

  # But we are editing directus.tf, not main.tf.

  # Alternative: Hardcode the assumption? No.

  # If we cannot change main.tf, we are stuck with the cycle if we use `local.nfs_internal_ip` here.
  # UNLESS `nfs.tf` does NOT depend on `local.final_nfs_enabled`?
  # `nfs.tf` uses `count = local.nfs_enabled ? 1 : 0`. `local.nfs_enabled` comes from `main.tf`.

  # Does `local.nfs_internal_ip` exist if `nfs_enabled` is false?
  # It is `try(..., "")`.

  # The cycle is strict.
  # We must supply the REDIS variable in a way that doesn't depend on the module configuration itself.

  # Can we set `REDIS` to a template string and replace it later? No easy way in Terraform without changing main.tf.

  # WAIT. If we look at `variables.tf`, we have `redis_host`.
  # If `redis_host` is provided, we don't need NFS IP.
  # If `redis_host` is missing, we need NFS IP.

  # If we cannot resolve the NFS IP here, we might have to rely on `directus_module` NOT defining `module_env_vars`
  # with the Redis string, and assume `main.tf` or another mechanism handles it?
  # But `main.tf` merges `local.module_env_vars`.

  # Let's try to break the chain by observing that `nfs_internal_ip` relies on `data.external`.
  # The data source depends on `local.nfs_enabled`.

  # What if we use `var.nfs_enabled` (if non-null) to short-circuit?
  # `local.final_nfs_enabled` in `main.tf` uses `var.nfs_enabled` if set.

  # If the user does not set `var.nfs_enabled`, it falls back to the module default.

  # The only way to fix this WITHOUT modifying main.tf is if the `REDIS` variable can be constructed
  # without referencing `local.nfs_internal_ip` directly.
  # But we need the IP.

  # What if we define `REDIS` as `redis://${DB_HOST}:6379`? No, DB host is different.
  # Use a DNS name? `nfs-server`? No.

  # Maybe we can use the `cloudrun-entrypoint` script to construct the env var at runtime?
  # We can pass `REDIS_HOST_OVERRIDE` and `REDIS_PORT`.
  # If `REDIS_HOST_OVERRIDE` is set, use it.
  # Else if NFS is enabled (detected via mount?), use NFS IP.
  # We can't easily detect NFS IP inside the container unless we mount it or pass it.

  # But wait, `directus.tf` is a "wrapper" configuration.
  # It seems `main.tf` is symlinked from `CloudRunApp` usually?
  # If `main.tf` is symlinked, we can't edit it easily for just this module without affecting others
  # (unless we copy it, which breaks the pattern).
  # Checking file list... `main.tf` is present in `modules/Directus/`.
  # Is it a symlink? `ls -F` earlier showed `@`.
  # Yes, `main.tf@`. So we CANNOT edit main.tf directly without affecting all modules.

  # SO: We must solve this in `directus.tf`.
  # But we cannot access `local.nfs_internal_ip` in `directus.tf`.

  # Let's look at `nfs.tf`. It is also a symlink (`nfs.tf@`).
  # So we cannot edit `nfs.tf`.

  # We are stuck.
  # 1. We need `REDIS` env var.
  # 2. It depends on `nfs_internal_ip`.
  # 3. `nfs_internal_ip` depends on `nfs_enabled`.
  # 4. `nfs_enabled` depends on `directus_module`.
  # 5. `directus_module` contains `REDIS` env var.

  # Breaking the link:
  # Can we use a separate resource to manage the Secret or Env Var injection?
  # We can create a `google_secret_manager_secret` for the Redis URL?
  # Then pass it as a secret env var?
  # `module_secret_env_vars` maps Name -> Secret ID.
  # We can calculate the secret value (string) using `local.nfs_internal_ip`.
  # Creating a resource (`google_secret_manager_secret_version`) depends on `local.nfs_internal_ip`.
  # Does `module_secret_env_vars` create a dependency back to `directus_module`?
  # `main.tf` uses `local.module_secret_env_vars` to construct `local.preset_secret_env_vars`.
  # This feeds into `local.secret_environment_variables`.
  # This feeds into `local.secret_env_var_map`.
  # This DOES NOT feed back into `local.final_nfs_enabled` or `local.directus_module`.

  # YES! `main.tf` logic:
  # `local.final_nfs_enabled` comes from `local.module_nfs_enabled`.
  # `local.module_nfs_enabled` comes from `local.selected_module.nfs_enabled`.
  # `local.selected_module` is `local.application_modules[...]`.

  # `local.module_secret_env_vars` is accessed via `local.module_secret_env_vars` directly in `main.tf` (line 331).
  # It is NOT accessed via `local.selected_module`.
  # Wait, `main.tf` has:
  # `preset_secret_env_vars = merge(..., local.module_secret_env_vars)`
  # It assumes `local.module_secret_env_vars` is defined in the wrapper's specific tf file.

  # So, if we define `REDIS_URL` via a Secret, we move the dependency out of the `directus_module` map.
  # The `directus_module` map (which causes the cycle via `nfs_enabled`) will no longer contain the dependency on `nfs_internal_ip`.
  # `local.module_secret_env_vars` will depend on `nfs_internal_ip`, but `directus_module` will not.
  # `main.tf` uses `directus_module` to determine NFS enabled -> `nfs.tf` calculates IP -> `directus.tf` uses IP for Secret -> `main.tf` uses Secret Map.
  # This is linear!

  # Plan:
  # 1. Create a `random_password` or just a `google_secret_manager_secret_version` with the Redis URL string.
  # 2. Add `REDIS` to `module_secret_env_vars` pointing to this secret.
  # 3. Remove `REDIS` from `module_env_vars`.

  redis_connection_string = var.redis_enabled ? (
    var.redis_host != "" ? "redis://${var.redis_host}:${var.redis_port}" :
    "redis://${local.nfs_internal_ip}:${var.redis_port}"
  ) : ""

  module_env_vars = {
    DB_HOST            = local.db_internal_ip
    DB_DATABASE        = local.database_name_full
    DB_USER            = local.database_user_full
    PUBLIC_URL         = local.predicted_service_url
    ADMIN_EMAIL        = try(local.final_environment_variables["ADMIN_EMAIL"], "admin@example.com")
    STORAGE_GCS_BUCKET = "${local.resource_prefix}-directus-uploads"
  }

  module_secret_env_vars = {
    KEY            = try(google_secret_manager_secret.directus_key.secret_id, "")
    SECRET         = try(google_secret_manager_secret.directus_secret.secret_id, "")
    ADMIN_PASSWORD = try(google_secret_manager_secret.directus_admin_password.secret_id, "")
    DB_PASSWORD    = try(google_secret_manager_secret.db_password[0].secret_id, "")
    REDIS          = var.redis_enabled ? try(google_secret_manager_secret.directus_redis[0].secret_id, "") : ""
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
# REDIS SECRET CONFIGURATION (To break dependency cycle)
# ==============================================================================

resource "google_secret_manager_secret" "directus_redis" {
  count     = var.redis_enabled ? 1 : 0
  secret_id = "${local.wrapper_prefix}-redis-url"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "directus_redis" {
  count       = var.redis_enabled ? 1 : 0
  secret      = google_secret_manager_secret.directus_redis[0].id
  secret_data = local.redis_connection_string
}

# Grant Cloud Run service account access to the Redis secret
# Note: iam.tf handles generic secret access if it iterates over all secrets?
# iam.tf iterates over `local.secret_environment_variables`.
# Since we added REDIS to `module_secret_env_vars`, it will be included in `local.secret_environment_variables`.
# So iam.tf will automatically grant access!


# ==============================================================================
# DIRECTUS SPECIFIC RESOURCES
# ==============================================================================

# Explicitly create the GCS bucket since we removed it from gcs_volumes
resource "google_storage_bucket" "directus_uploads" {
  name                        = "${local.resource_prefix}-directus-uploads"
  location                    = var.deployment_region
  storage_class               = "STANDARD"
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "inherited"

  lifecycle {
    prevent_destroy = false
  }
}

# Grant Cloud Run Service Account access to the bucket
resource "google_storage_bucket_iam_member" "directus_uploads_admin" {
  bucket = google_storage_bucket.directus_uploads.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.cloud_run_sa_email}"
}

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
