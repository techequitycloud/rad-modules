module "directus_module" {
  source = "./modules/directus"
}

locals {
  application_modules = {
    directus = module.directus_module.directus_module
  }
}

locals {
  application_modules = {
    directus = module.directus_module
  }

  module_env_vars = {
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
  }

  module_secret_env_vars = {
    KEY            = try(google_secret_manager_secret.directus_key.secret_id, "")
    SECRET         = try(google_secret_manager_secret.directus_secret.secret_id, "")
    ADMIN_PASSWORD = try(google_secret_manager_secret.directus_admin_password.secret_id, "")
    DB_PASSWORD    = try(google_secret_manager_secret.db_password[0].secret_id, "")
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
# DIRECTUS SPECIFIC RESOURCES
# ==============================================================================
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
