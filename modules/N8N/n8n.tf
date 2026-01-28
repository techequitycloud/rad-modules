module "n8n_module" {
  source = "./modules/n8n"
}

locals {
  application_modules = {
    n8n = module.n8n_module.n8n_module
  }
}

locals {
  n8n_env_vars = var.application_module == "n8n" ? {
    N8N_PORT                     = "5678"
    N8N_PROTOCOL                 = "https"
    N8N_DIAGNOSTICS_ENABLED      = "true"
    N8N_METRICS                  = "true"
    DB_TYPE                      = "postgresdb"
    DB_POSTGRESDB_DATABASE       = local.database_name_full
    DB_POSTGRESDB_USER           = local.database_user_full
    DB_POSTGRESDB_HOST           = local.db_internal_ip
    N8N_DEFAULT_BINARY_DATA_MODE = "filesystem"
    WEBHOOK_URL                  = local.predicted_service_url
    N8N_EDITOR_BASE_URL          = local.predicted_service_url
  } : {}

  n8n_secret_env_vars = var.application_module == "n8n" ? {
    N8N_ENCRYPTION_KEY     = try(google_secret_manager_secret.encryption_key[0].secret_id, "")
    DB_POSTGRESDB_PASSWORD = try(google_secret_manager_secret.db_password[0].secret_id, "")
    N8N_SMTP_PASS          = try(google_secret_manager_secret.n8n_smtp_password[0].secret_id, "")
  } : {}

  n8n_storage_buckets = var.application_module == "n8n" ? [
    {
      name_suffix              = "n8n-data"
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
# N8N SPECIFIC RESOURCES
# ==============================================================================
resource "google_storage_bucket" "n8n_storage" {
  count                       = var.application_module == "n8n" ? 1 : 0
  name                        = "${local.wrapper_prefix}-storage"
  location                    = var.deployment_region
  force_destroy               = true
  project                     = var.existing_project_id
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "n8n_cloudrun_access" {
  count  = var.application_module == "n8n" ? 1 : 0
  bucket = google_storage_bucket.n8n_storage[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.cloud_run_sa_email}"
}

resource "random_password" "n8n_smtp_password_dummy" {
  count   = var.application_module == "n8n" ? 1 : 0
  length  = 16
  special = false
}

resource "google_secret_manager_secret" "n8n_smtp_password" {
  count     = var.application_module == "n8n" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-smtp-password"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "n8n_smtp_password" {
  count       = var.application_module == "n8n" ? 1 : 0
  secret      = google_secret_manager_secret.n8n_smtp_password[0].id
  secret_data = random_password.n8n_smtp_password_dummy[0].result
}

resource "random_password" "encryption_key" {
  count   = var.application_module == "n8n" ? 1 : 0
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "encryption_key" {
  count     = var.application_module == "n8n" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-encryption-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "encryption_key" {
  count       = var.application_module == "n8n" ? 1 : 0
  secret      = google_secret_manager_secret.encryption_key[0].id
  secret_data = random_password.encryption_key[0].result
}
