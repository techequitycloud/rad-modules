module "django_module" {
  source = "./modules/django"
}

locals {
  application_modules = {
    django = module.django_module.django_module
  }

  module_env_vars = var.application_module == "django" ? {
    CLOUDRUN_SERVICE_URLS = local.predicted_service_url
  } : {}

  module_secret_env_vars = var.application_module == "django" ? {
    DJANGO_SUPERUSER_PASSWORD = try(google_secret_manager_secret.db_password[0].secret_id, "")
    SECRET_KEY                = try(google_secret_manager_secret.django_secret_key[0].secret_id, "")
  } : {}

  module_storage_buckets = var.application_module == "django" ? [
    {
      name_suffix              = "django-media"
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
# DJANGO SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "django_secret_key" {
  count   = var.application_module == "django" ? 1 : 0
  length  = 50
  special = false
}

resource "google_secret_manager_secret" "django_secret_key" {
  count     = var.application_module == "django" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-secret-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "django_secret_key" {
  count       = var.application_module == "django" ? 1 : 0
  secret      = google_secret_manager_secret.django_secret_key[0].id
  secret_data = random_password.django_secret_key[0].result
}
