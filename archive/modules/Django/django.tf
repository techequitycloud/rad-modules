locals {
  # Determine Redis host:
  # 1. Use provided redis_host if specified.
  # 2. If redis_host is empty, try to use NFS server IP (if NFS exists).
  # 3. If neither, leave empty (application should handle missing Redis configuration or fail if strictly required).
  redis_host_final = var.enable_redis ? (
    var.redis_host != "" ? var.redis_host : (local.nfs_server_exists ? local.nfs_internal_ip : "")
  ) : ""

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
        script_path       = "${path.module}/scripts/django/db-init.sh"
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
      },
      {
        name            = "migrate"
        description     = "Run Django Migrations"
        image           = null
        script_path       = "${path.module}/scripts/django/migrate.sh"
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

  module_env_vars = merge({
    CLOUDRUN_SERVICE_URLS = local.predicted_service_url
    GS_BUCKET_NAME        = "${local.wrapper_prefix}-django-media"
    }, var.enable_redis ? {
    REDIS_HOST = local.redis_host_final
    REDIS_PORT = var.redis_port
    REDIS_URL  = "redis://${local.redis_host_final}:${var.redis_port}/0"
  } : {})

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
