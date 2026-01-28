module "wordpress_module" {
  source = "./modules/wordpress"
}

locals {
  application_modules = {
    wordpress = module.wordpress_module.wordpress_module
  }

  module_env_vars = var.application_module == "wordpress" ? {
    WORDPRESS_DB_NAME = local.database_name_full
    WORDPRESS_DB_USER = local.database_user_full
    WORDPRESS_DB_HOST = local.db_internal_ip
    WORDPRESS_DEBUG   = "false"
  } : {}

  module_secret_env_vars = var.application_module == "wordpress" ? {
    WORDPRESS_DB_PASSWORD = try(google_secret_manager_secret.db_password[0].secret_id, "")
  } : {}

  module_storage_buckets = var.application_module == "wordpress" ? [
    {
      name_suffix                   = "wp-uploads"
      location                      = var.deployment_region
      storage_class                 = "STANDARD"
      force_destroy                 = true
      versioning_enabled            = false
      lifecycle_rules               = []
      public_access_prevention      = "inherited"
      soft_delete_retention_seconds = 0
    }
  ] : []
}
