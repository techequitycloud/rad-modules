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
    enable_nfs    = true
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
      CACHE_ENABLED = tostring(var.enable_redis)
      CACHE_STORE   = var.enable_redis ? "redis" : "memory"
      # REDIS value is injected via module_env_vars to avoid cycle with enable_nfs
      
      # Rate limiting
      RATE_LIMITER_ENABLED  = "false"
      RATE_LIMITER_POINTS   = "50"
      RATE_LIMITER_DURATION = "1"

      # Storage configuration - Use GCS native driver
      STORAGE_LOCATIONS  = "gcs"
      STORAGE_GCS_DRIVER = "gcs"

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
        script_path       = "${path.module}/scripts/directus/db-init.sh"
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
        script_path       = "${path.module}/scripts/directus/directus-bootstrap.sh"
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

  redis_connection_string = var.enable_redis ? (
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

  module_secret_env_vars = merge(
    {
      KEY            = try(google_secret_manager_secret.directus_key.secret_id, "")
      SECRET         = try(google_secret_manager_secret.directus_secret.secret_id, "")
      ADMIN_PASSWORD = try(google_secret_manager_secret.directus_admin_password.secret_id, "")
      DB_PASSWORD    = try(google_secret_manager_secret.db_password[0].secret_id, "")
    },
    var.enable_redis ? {
      REDIS = try(google_secret_manager_secret.directus_redis[0].secret_id, "")
    } : {}
  )

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
  count     = var.enable_redis ? 1 : 0
  secret_id = "${local.wrapper_prefix}-redis-url"
  replication {
    auto {}
  }
  project = var.existing_project_id
  labels  = local.common_labels
}

resource "google_secret_manager_secret_version" "directus_redis" {
  count       = var.enable_redis ? 1 : 0
  secret      = google_secret_manager_secret.directus_redis[0].id
  secret_data = local.redis_connection_string
}

# ==============================================================================
# DIRECTUS SPECIFIC RESOURCES
# ==============================================================================

# Grant Cloud Run Service Account access to the bucket
# Note: The bucket is created via module_storage_buckets logic in main.tf (storage.tf), 
# because we included it in `module_storage_buckets`.
# So we don't need to create it here again.
# We just need to ensure permissions.
# `storage.tf` creates `google_storage_bucket.buckets` based on `local.storage_buckets`.

# Wait, `module_storage_buckets` logic in `main.tf`:
# storage_buckets = local.create_cloud_storage ? { for bucket in local.all_storage_buckets ... }
# all_storage_buckets = concat(var.storage_buckets, local.preset_storage_buckets)
# preset_storage_buckets = concat(local.module_storage_buckets)
# So yes, the bucket IS created by `main.tf` -> `storage.tf`.
# The previous `gcs_volumes` logic was separate or supplementary?
# Ah, `gcs_volumes` usually implies mounting. If `bucket_name` is null, does it create it?
# In `main.tf`, `gcs_volumes` logic: `bucket_name = (vol.bucket_name != null ...) ? ... : try(local.storage_buckets[vol.name].name, null)`
# It tries to find the bucket in `local.storage_buckets`.
# So the bucket creation was ALWAYS driven by `module_storage_buckets` (or `var.storage_buckets`).
# `gcs_volumes` just referenced it.

# Therefore:
# 1. We keep `module_storage_buckets` (we have it).
# 2. `storage.tf` creates the bucket.
# 3. `iam.tf` grants `roles/storage.objectAdmin` to `local.cloud_run_sa_email` for all buckets in `local.storage_buckets`.
#    Checking `iam.tf`:
#    resource "google_storage_bucket_iam_member" "bucket_access" {
#      for_each = local.create_cloud_storage ? local.storage_buckets : {}
#      bucket = google_storage_bucket.buckets[each.key].name
#      role   = "roles/storage.objectAdmin"
#      member = "serviceAccount:${local.cloud_run_sa_email}"
#    }

# CONCLUSION:
# - We do NOT need `resource "google_storage_bucket" "directus_uploads"` here. (It duplicates main.tf/storage.tf).
# - We do NOT need explicit IAM binding here. (`iam.tf` handles it).

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
  labels  = local.common_labels
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
  labels  = local.common_labels
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
  labels  = local.common_labels
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
