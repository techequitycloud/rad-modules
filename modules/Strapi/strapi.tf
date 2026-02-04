locals {
  strapi_module = {
    app_name            = "strapi"
    display_name        = "Strapi CMS"
    description         = "Strapi - Open source Node.js Headless CMS"
    container_image     = ""
    image_source        = "custom"
    application_version = var.application_version

    enable_image_mirroring = false

    # Custom build configuration
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "strapi"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = null
    }

    container_port  = 1337
    database_type   = "POSTGRES_15"
    db_name         = "strapi"
    db_user         = "strapi"

    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    # Resource limits
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "1Gi"
    }
    min_instance_count = 0
    max_instance_count = 3

    # Environment variables
    environment_variables = {
      NODE_ENV        = "production"
      DATABASE_CLIENT = "postgres"
      DATABASE_SSL    = "false"
      # DB connection details will be injected by main.tf

      # SMTP Configuration
      SMTP_HOST      = ""
      SMTP_PORT      = ""
      SMTP_USERNAME  = ""
      # SMTP_PASSWORD should be passed via secrets
      EMAIL_FROM     = ""
      EMAIL_REPLY_TO = ""

      # GCS Configuration
      GCS_PUBLIC_FILES = "true"
      GCS_UNIFORM      = "true"
    }

    # Initialization Jobs
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Strapi Database and User"
        image           = "alpine:3.19"
        script_path       = "${path.module}/scripts/strapi/db-init.sh"
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
      }
    ]

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 10
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/_health"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
  }

  application_modules = {
    strapi = local.strapi_module
  }

  # Environment Variables Mapping
  # Maps infrastructure values (IPs, Secrets) to Application Env Vars
  module_env_vars = merge({
    DATABASE_HOST     = local.db_internal_ip
    DATABASE_PORT     = "5432"
    DATABASE_NAME     = local.database_name_full
    DATABASE_USERNAME = local.database_user_full
    STRAPI_URL        = local.predicted_service_url
    GCS_BUCKET_NAME   = try(local.storage_buckets["strapi-uploads"].name, "")
    GCS_BASE_URL      = "https://storage.googleapis.com/${try(local.storage_buckets["strapi-uploads"].name, "")}"
    },
    var.redis_enabled && (var.redis_host != null && var.redis_host != "" || try(local.nfs_internal_ip, "") != "") ? {
      REDIS_HOST = var.redis_host != null && var.redis_host != "" ? var.redis_host : local.nfs_internal_ip
      REDIS_PORT = var.redis_port
    } : {}
  )

  module_secret_env_vars = {
    DATABASE_PASSWORD   = try(google_secret_manager_secret.db_password[0].secret_id, "")
    JWT_SECRET          = try(google_secret_manager_secret.strapi_jwt_secret.secret_id, "")
    ADMIN_JWT_SECRET    = try(google_secret_manager_secret.strapi_admin_jwt_secret.secret_id, "")
    API_TOKEN_SALT      = try(google_secret_manager_secret.strapi_api_token_salt.secret_id, "")
    TRANSFER_TOKEN_SALT = try(google_secret_manager_secret.strapi_transfer_token_salt.secret_id, "")
    APP_KEYS            = try(google_secret_manager_secret.strapi_app_keys.secret_id, "")
  }

  module_storage_buckets = [
    {
      name_suffix              = "strapi-uploads"
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
# STRAPI SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "strapi_jwt_secret" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_jwt_secret" {
  secret_id = "${local.wrapper_prefix}-jwt-secret"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_jwt_secret" {
  secret      = google_secret_manager_secret.strapi_jwt_secret.id
  secret_data = random_password.strapi_jwt_secret.result
}

resource "random_password" "strapi_admin_jwt_secret" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_admin_jwt_secret" {
  secret_id = "${local.wrapper_prefix}-admin-jwt-secret"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_admin_jwt_secret" {
  secret      = google_secret_manager_secret.strapi_admin_jwt_secret.id
  secret_data = random_password.strapi_admin_jwt_secret.result
}

resource "random_password" "strapi_api_token_salt" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_api_token_salt" {
  secret_id = "${local.wrapper_prefix}-api-token-salt"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_api_token_salt" {
  secret      = google_secret_manager_secret.strapi_api_token_salt.id
  secret_data = random_password.strapi_api_token_salt.result
}

resource "random_password" "strapi_transfer_token_salt" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_transfer_token_salt" {
  secret_id = "${local.wrapper_prefix}-transfer-token-salt"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_transfer_token_salt" {
  secret      = google_secret_manager_secret.strapi_transfer_token_salt.id
  secret_data = random_password.strapi_transfer_token_salt.result
}

resource "random_password" "strapi_app_key_1" {
  length  = 32
  special = false
}
resource "random_password" "strapi_app_key_2" {
  length  = 32
  special = false
}
resource "random_password" "strapi_app_key_3" {
  length  = 32
  special = false
}
resource "random_password" "strapi_app_key_4" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_app_keys" {
  secret_id = "${local.wrapper_prefix}-app-keys"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_app_keys" {
  secret      = google_secret_manager_secret.strapi_app_keys.id
  secret_data = "${random_password.strapi_app_key_1.result},${random_password.strapi_app_key_2.result},${random_password.strapi_app_key_3.result},${random_password.strapi_app_key_4.result}"
}
