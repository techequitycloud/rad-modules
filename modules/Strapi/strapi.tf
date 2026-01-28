module "strapi_module" {
  source = "./modules/strapi"
}

locals {
  application_modules = {
    strapi = module.strapi_module.strapi_module
  }

  strapi_env_vars = var.application_module == "strapi" ? {
    DATABASE_HOST     = local.db_internal_ip
    DATABASE_PORT     = "5432"
    DATABASE_NAME     = local.database_name_full
    DATABASE_USERNAME = local.database_user_full
    STRAPI_URL        = local.predicted_service_url
    GCS_BUCKET_NAME   = try(local.storage_buckets["strapi-uploads"].name, "")
  } : {}

  strapi_secret_env_vars = var.application_module == "strapi" ? {
    DATABASE_PASSWORD   = try(google_secret_manager_secret.db_password[0].secret_id, "")
    JWT_SECRET          = try(google_secret_manager_secret.strapi_jwt_secret[0].secret_id, "")
    ADMIN_JWT_SECRET    = try(google_secret_manager_secret.strapi_admin_jwt_secret[0].secret_id, "")
    API_TOKEN_SALT      = try(google_secret_manager_secret.strapi_api_token_salt[0].secret_id, "")
    TRANSFER_TOKEN_SALT = try(google_secret_manager_secret.strapi_transfer_token_salt[0].secret_id, "")
    APP_KEYS            = try(google_secret_manager_secret.strapi_app_keys[0].secret_id, "")
  } : {}

  strapi_storage_buckets = var.application_module == "strapi" ? [
    {
      name_suffix              = "strapi-uploads"
      location                 = var.deployment_region
      storage_class            = "STANDARD"
      force_destroy            = true
      versioning_enabled       = false
      lifecycle_rules          = []
      public_access_prevention = "inherited"
    }
  ] : []

  # Generic mappings
  module_env_vars        = local.strapi_env_vars
  module_secret_env_vars = local.strapi_secret_env_vars
  module_storage_buckets = local.strapi_storage_buckets
}

# ==============================================================================
# STRAPI SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "strapi_jwt_secret" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_jwt_secret" {
  count     = var.application_module == "strapi" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-jwt-secret"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_jwt_secret" {
  count       = var.application_module == "strapi" ? 1 : 0
  secret      = google_secret_manager_secret.strapi_jwt_secret[0].id
  secret_data = random_password.strapi_jwt_secret[0].result
}

resource "random_password" "strapi_admin_jwt_secret" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_admin_jwt_secret" {
  count     = var.application_module == "strapi" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-admin-jwt-secret"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_admin_jwt_secret" {
  count       = var.application_module == "strapi" ? 1 : 0
  secret      = google_secret_manager_secret.strapi_admin_jwt_secret[0].id
  secret_data = random_password.strapi_admin_jwt_secret[0].result
}

resource "random_password" "strapi_api_token_salt" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_api_token_salt" {
  count     = var.application_module == "strapi" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-api-token-salt"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_api_token_salt" {
  count       = var.application_module == "strapi" ? 1 : 0
  secret      = google_secret_manager_secret.strapi_api_token_salt[0].id
  secret_data = random_password.strapi_api_token_salt[0].result
}

resource "random_password" "strapi_transfer_token_salt" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_transfer_token_salt" {
  count     = var.application_module == "strapi" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-transfer-token-salt"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_transfer_token_salt" {
  count       = var.application_module == "strapi" ? 1 : 0
  secret      = google_secret_manager_secret.strapi_transfer_token_salt[0].id
  secret_data = random_password.strapi_transfer_token_salt[0].result
}

resource "random_password" "strapi_app_key_1" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}
resource "random_password" "strapi_app_key_2" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}
resource "random_password" "strapi_app_key_3" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}
resource "random_password" "strapi_app_key_4" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_app_keys" {
  count     = var.application_module == "strapi" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-app-keys"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_app_keys" {
  count       = var.application_module == "strapi" ? 1 : 0
  secret      = google_secret_manager_secret.strapi_app_keys[0].id
  secret_data = "${random_password.strapi_app_key_1[0].result},${random_password.strapi_app_key_2[0].result},${random_password.strapi_app_key_3[0].result},${random_password.strapi_app_key_4[0].result}"
}
