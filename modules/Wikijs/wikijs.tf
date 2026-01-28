module "wikijs_module" {
  source = "./modules/wikijs"
}

locals {
  application_modules = {
    wikijs = module.wikijs_module.wikijs_module
  }

  module_env_vars = var.application_module == "wikijs" ? {
    DB_HOST    = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    REDIS_HOST = local.nfs_server_exists ? local.nfs_internal_ip : ""
    REDIS_PORT = local.nfs_server_exists ? "6379" : ""
  } : {}

  module_secret_env_vars = var.application_module == "wikijs" ? {
    DB_PASS = try(google_secret_manager_secret.db_password[0].secret_id, "")
  } : {}

  module_storage_buckets = var.application_module == "wikijs" ? [
    {
      name_suffix              = "wikijs-storage"
      location                 = var.deployment_region
      storage_class            = "STANDARD"
      force_destroy            = true
      versioning_enabled       = false
      lifecycle_rules          = []
      public_access_prevention = "inherited"
    }
  ] : []
}
