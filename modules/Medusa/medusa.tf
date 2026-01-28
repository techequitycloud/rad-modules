module "medusa_module" {
  source = "./modules/medusa"
}

locals {
  application_modules = {
    medusa = module.medusa_module.medusa_module
  }
}

locals {
  application_modules = {
    medusa = module.medusa_module.medusa_module
  }

  module_env_vars = var.application_module == "medusa" ? {
    DB_HOST                   = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    DB_PORT                   = "5432"
    DB_NAME                   = local.database_name_full
    DB_USER                   = local.database_user_full
    REDIS_URL                 = local.nfs_enabled ? "redis://${local.nfs_internal_ip}:6379" : ""
    MEDUSA_FILE_GOOGLE_BUCKET = try(local.storage_buckets["medusa-uploads"].name, "")
  } : {}

  module_secret_env_vars = var.application_module == "medusa" ? {
    DB_PASSWORD   = try(google_secret_manager_secret.db_password[0].secret_id, "")
    JWT_SECRET    = try(google_secret_manager_secret.medusa_jwt_secret[0].secret_id, "")
    COOKIE_SECRET = try(google_secret_manager_secret.medusa_cookie_secret[0].secret_id, "")
  } : {}

  module_storage_buckets = var.application_module == "medusa" ? [
    {
      name_suffix              = "medusa-uploads"
      location                 = var.deployment_region
      storage_class            = "STANDARD"
      force_destroy            = true
      versioning_enabled       = false
      lifecycle_rules          = []
      public_access_prevention = "inherited"
    }
  ] : []
}

# ==============================================================================
# MEDUSA SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "medusa_jwt_secret" {
  count   = var.application_module == "medusa" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "medusa_jwt_secret" {
  count     = var.application_module == "medusa" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-jwt-secret"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "medusa_jwt_secret" {
  count       = var.application_module == "medusa" ? 1 : 0
  secret      = google_secret_manager_secret.medusa_jwt_secret[0].id
  secret_data = random_password.medusa_jwt_secret[0].result
}

resource "random_password" "medusa_cookie_secret" {
  count   = var.application_module == "medusa" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "medusa_cookie_secret" {
  count     = var.application_module == "medusa" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-cookie-secret"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "medusa_cookie_secret" {
  count       = var.application_module == "medusa" ? 1 : 0
  secret      = google_secret_manager_secret.medusa_cookie_secret[0].id
  secret_data = random_password.medusa_cookie_secret[0].result
}
