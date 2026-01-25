locals {
  directus_env_vars = var.application_module == "directus" ? {
    DB_CLIENT              = "pg"
    DB_HOST                = local.db_internal_ip
    DB_PORT                = "5432"
    DB_DATABASE            = local.database_name_full
    DB_USER                = local.database_user_full
    PUBLIC_URL             = local.predicted_service_url
    STORAGE_LOCATIONS      = "uploads"
    STORAGE_UPLOADS_DRIVER = "local"
    STORAGE_UPLOADS_ROOT   = "/mnt/directus-uploads"
    WEBSOCKETS_ENABLED     = "true"
    # CORS configuration removed from here to allow user override via environment_variables
    ADMIN_EMAIL            = try(local.final_environment_variables["ADMIN_EMAIL"], "admin@example.com")
  } : {}

  directus_secret_env_vars = var.application_module == "directus" ? {
    KEY            = try(google_secret_manager_secret.directus_key[0].secret_id, "")
    SECRET         = try(google_secret_manager_secret.directus_secret[0].secret_id, "")
    ADMIN_PASSWORD = try(google_secret_manager_secret.directus_admin_password[0].secret_id, "")
    DB_PASSWORD    = try(google_secret_manager_secret.db_password[0].secret_id, "")
  } : {}

  directus_storage_buckets = var.application_module == "directus" ? [
    {
      name_suffix              = "directus-uploads"
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
# DIRECTUS SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "directus_key" {
  count   = var.application_module == "directus" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "directus_key" {
  count     = var.application_module == "directus" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "directus_key" {
  count       = var.application_module == "directus" ? 1 : 0
  secret      = google_secret_manager_secret.directus_key[0].id
  secret_data = random_password.directus_key[0].result
}

resource "random_password" "directus_secret" {
  count   = var.application_module == "directus" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "directus_secret" {
  count     = var.application_module == "directus" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-secret-app"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "directus_secret" {
  count       = var.application_module == "directus" ? 1 : 0
  secret      = google_secret_manager_secret.directus_secret[0].id
  secret_data = random_password.directus_secret[0].result
}

resource "random_password" "directus_admin_password" {
  count   = var.application_module == "directus" ? 1 : 0
  length  = 20
  special = false
}

resource "google_secret_manager_secret" "directus_admin_password" {
  count     = var.application_module == "directus" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-admin-password"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "directus_admin_password" {
  count       = var.application_module == "directus" ? 1 : 0
  secret      = google_secret_manager_secret.directus_admin_password[0].id
  secret_data = random_password.directus_admin_password[0].result
}
