module "openemr_module" {
  source      = "./modules/openemr"
}

locals {
  application_modules = {
    openemr = module.openemr_module.openemr_module
  }

  module_env_vars = var.application_module == "openemr" ? {
    MYSQL_DATABASE = local.database_name_full
    MYSQL_USER     = local.database_user_full
    MYSQL_HOST     = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    MYSQL_PORT     = "3306"
    OE_USER        = "admin"
    MANUAL_SETUP   = "no"
    BACKUP_FILEID  = local.final_backup_uri != null ? local.final_backup_uri : ""
    SWARM_MODE     = "no"
    REDIS_SERVER   = local.nfs_server_exists ? local.nfs_internal_ip : ""
    REDIS_PORT     = "6379"
  } : {}

  module_secret_env_vars = var.application_module == "openemr" ? {
    MYSQL_ROOT_PASS = "${local.db_instance_name}-root-password"
    OE_PASS         = try(google_secret_manager_secret.openemr_admin_password[0].secret_id, "")
    MYSQL_PASS      = try(google_secret_manager_secret.db_password[0].secret_id, "")
  } : {}

  module_storage_buckets = []
}

# ==============================================================================
# OPENEMR SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "openemr_admin_password" {
  count   = var.application_module == "openemr" ? 1 : 0
  length  = 20
  special = false
}

resource "google_secret_manager_secret" "openemr_admin_password" {
  count     = var.application_module == "openemr" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-admin-password"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "openemr_admin_password" {
  count       = var.application_module == "openemr" ? 1 : 0
  secret      = google_secret_manager_secret.openemr_admin_password[0].id
  secret_data = random_password.openemr_admin_password[0].result
}
