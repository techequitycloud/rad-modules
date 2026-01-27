locals {
  odoo_env_vars = var.application_module == "odoo" ? {
    HOST    = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    DB_HOST = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    USER    = local.database_user_full
    DB_PORT = "5432"
    PGPORT  = "5432"
  } : {}

  odoo_secret_env_vars = var.application_module == "odoo" ? {
    ODOO_MASTER_PASS = try(google_secret_manager_secret.odoo_master_pass[0].secret_id, "")
  } : {}

  odoo_storage_buckets = var.application_module == "odoo" ? [
    {
      name_suffix              = "odoo-addons-volume"
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
# ODOO SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "odoo_master_pass" {
  count   = var.application_module == "odoo" ? 1 : 0
  length  = 16
  special = false
}

resource "google_secret_manager_secret" "odoo_master_pass" {
  count     = var.application_module == "odoo" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-master-pass"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "odoo_master_pass" {
  count       = var.application_module == "odoo" ? 1 : 0
  secret      = google_secret_manager_secret.odoo_master_pass[0].id
  secret_data = random_password.odoo_master_pass[0].result
}
