module "odoo_module" {
  source = "./modules/odoo"
}

locals {
  application_modules = {
    "odoo" = module.odoo_module.odoo_module
  }

  odoo_env_vars = {
    HOST    = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    DB_HOST = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    USER    = local.database_user_full
    DB_PORT = "5432"
    PGPORT  = "5432"
  }

  odoo_secret_env_vars = {
    ODOO_MASTER_PASS = try(google_secret_manager_secret.odoo_master_pass.secret_id, "")
  }

  odoo_storage_buckets = [
    {
      name_suffix              = "odoo-addons"
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
# ODOO SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "odoo_master_pass" {
  length  = 16
  special = false
}

resource "google_secret_manager_secret" "odoo_master_pass" {
  secret_id = "${local.wrapper_prefix}-master-pass"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "odoo_master_pass" {
  secret      = google_secret_manager_secret.odoo_master_pass.id
  secret_data = random_password.odoo_master_pass.result
}
