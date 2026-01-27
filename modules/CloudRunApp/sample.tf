locals {
  sample_env_vars = var.application_module == "sample" ? {
    DB_HOST = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip

    # Redis Configuration for Caching
    CACHE_ENABLED          = "true"
    CACHE_STORE            = "redis"
    REDIS                  = "redis://${local.nfs_internal_ip}:6379"
  } : {}

  sample_secret_env_vars = {}

  sample_storage_buckets = []
}
