locals {
  cyclos_env_vars = var.application_module == "cyclos" ? {
    DB_HOST      = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    DB_HOST_JDBC = local.enable_cloudsql_volume ? replace("${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}", "/", "%2F") : local.db_internal_ip
  } : {}

  cyclos_secret_env_vars = {}

  cyclos_storage_buckets = []
}
