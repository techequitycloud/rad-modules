module "moodle_module" {
  source = "./modules/moodle"
}

locals {
  application_modules = {
    moodle = module.moodle_module.moodle_module
  }
}

locals {
  moodle_env_vars = var.application_module == "moodle" ? {
    # Database connection (supports both MySQL and PostgreSQL)
    MOODLE_DB_HOST = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    MOODLE_DB_PORT = tostring(local.database_port)
    MOODLE_DB_USER = local.database_user_full
    MOODLE_DB_NAME = local.database_name_full

    # Database type: "pgsql" for PostgreSQL, "mysqli" for MySQL
    MOODLE_DB_TYPE = local.database_client_type == "POSTGRES" ? "pgsql" : "mysqli"

    # Redis Configuration
    MOODLE_REDIS_HOST = local.nfs_enabled ? local.nfs_internal_ip : ""

    # SMTP Configuration
    MOODLE_SMTP_HOST   = ""
    MOODLE_SMTP_PORT   = "587"
    MOODLE_SMTP_USER   = ""
    MOODLE_SMTP_SECURE = "tls"
    MOODLE_SMTP_AUTH   = "LOGIN"

    # Pre-calculated Cloud Run URL (deterministic format)
    MOODLE_WWWROOT  = local.predicted_service_url
    MOODLE_SITE_URL = local.predicted_service_url
    MOODLE_URL      = local.predicted_service_url
    APP_URL         = local.predicted_service_url

    # Reverse Proxy Support (CRITICAL for Cloud Run)
    ENABLE_REVERSE_PROXY = "TRUE"
    MOODLE_REVERSE_PROXY = "true"

    # Cron Configuration (Managed by Cloud Scheduler)
    # CRON_INTERVAL = "1" # Deprecated

    # Site configuration
    MOODLE_SITE_NAME     = "Moodle LMS"
    MOODLE_SITE_FULLNAME = "Moodle Learning Management System"
    LANGUAGE             = "en"
    MOODLE_ADMIN_USER    = "admin"
    MOODLE_ADMIN_EMAIL   = "admin@example.com"

    # Installation settings
    MOODLE_SKIP_INSTALL = "no"
    MOODLE_UPDATE       = "yes"

    # Data directory
    MOODLE_DATA_DIR = "/mnt"
    DATA_PATH       = "/mnt"
  } : {}

  moodle_secret_env_vars = var.application_module == "moodle" ? {
    MOODLE_DB_PASSWORD   = try(google_secret_manager_secret.db_password[0].secret_id, "")
    MOODLE_CRON_PASSWORD = try(google_secret_manager_secret.moodle_cron_password[0].secret_id, "")
    MOODLE_SMTP_PASSWORD = try(google_secret_manager_secret.moodle_smtp_password[0].secret_id, "")
  } : {}

  moodle_storage_buckets = var.application_module == "moodle" ? [
    {
      name_suffix              = "moodle-data"
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
# MOODLE SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "moodle_cron_password" {
  count   = var.application_module == "moodle" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "moodle_cron_password" {
  count     = var.application_module == "moodle" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-cron-password"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "moodle_cron_password" {
  count       = var.application_module == "moodle" ? 1 : 0
  secret      = google_secret_manager_secret.moodle_cron_password[0].id
  secret_data = random_password.moodle_cron_password[0].result
}

resource "google_secret_manager_secret" "moodle_smtp_password" {
  count     = var.application_module == "moodle" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-smtp-password"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_cloud_scheduler_job" "moodle_cron_job" {
  count            = var.application_module == "moodle" ? 1 : 0
  name             = "${local.resource_prefix}-moodle-cron"
  description      = "Trigger Moodle Cron"
  schedule         = "* * * * *"
  time_zone        = "Etc/UTC"
  attempt_deadline = "320s"
  project          = var.existing_project_id
  region           = var.deployment_region

  http_target {
    http_method = "GET"
    uri         = "${local.predicted_service_url}/admin/cron.php?password=${random_password.moodle_cron_password[0].result}"
  }
}
