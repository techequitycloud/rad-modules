locals {
  ghost_env_vars = var.application_module == "ghost" ? {
    url                            = local.predicted_service_url
    database__connection__host     = local.db_internal_ip
    database__connection__user     = local.database_user_full
    database__connection__database = local.database_name_full
    database__connection__port     = "3306"
    database__connection__socketPath = ""
  } : {}

  ghost_secret_env_vars = var.application_module == "ghost" ? {
    database__connection__password = try(google_secret_manager_secret.db_password[0].secret_id, "")
  } : {}

  ghost_storage_buckets = var.application_module == "ghost" ? [
    {
      name_suffix              = "ghost-content"
      location                 = var.deployment_region
      storage_class            = "STANDARD"
      force_destroy            = true
      versioning_enabled       = false
      lifecycle_rules          = []
      public_access_prevention = "inherited"
    }
  ] : []
}
