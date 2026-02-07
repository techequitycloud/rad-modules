locals {
  wordpress_module = {
    app_name            = "wp"
    description         = "WordPress CMS - Popular content management system for websites and blogs"
    container_image     = "wordpress"
    container_port      = 80
    database_type       = "MYSQL_8_0"
    db_name             = "wp"
    db_user             = "wp"
    application_version = var.application_version

    image_source           = "prebuilt"
    enable_image_mirroring = true

    # ✅ Custom build configuration
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "wordpress"
      dockerfile_content = null
      build_args = {
        APP_VERSION         = var.application_version
        PHP_MEMORY_LIMIT    = var.php_memory_limit
        UPLOAD_MAX_FILESIZE = var.upload_max_filesize
        POST_MAX_SIZE       = var.post_max_size
      }
      artifact_repo_name = null
    }

    # Performance optimization
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    # Storage volumes
    gcs_volumes = [{
      name          = "wp-uploads"
      mount_path    = "/var/www/html/wp-content"
      read_only     = false
      mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
    }]

    # Resource limits
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "2Gi"
    }
    min_instance_count = 1
    max_instance_count = 3

    # Environment variables
    environment_variables = merge({
      WORDPRESS_DB_HOST      = "localhost:/cloudsql/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}"
      WORDPRESS_TABLE_PREFIX = "wp_"
      WORDPRESS_DEBUG        = "false"
    }, var.enable_redis && var.redis_host != "" ? { WP_REDIS_HOST = var.redis_host } : {},
       var.enable_redis ? { WP_REDIS_PORT = var.redis_port } : {}
    )

    # MySQL plugins
    enable_mysql_plugins = false
    mysql_plugins        = []

    # Initialization Jobs
    initialization_jobs = [
      {
        name        = "db-init"
        description = "Create WordPress Database and User"
        image       = "alpine:3.19"
        script_path       = "${path.module}/scripts/wordpress/db-init.sh"
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
      }
    ]

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 30
      timeout_seconds       = 10
      period_seconds        = 15
      failure_threshold     = 20
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/wp-admin/install.php"
      initial_delay_seconds = 300
      timeout_seconds       = 60
      period_seconds        = 60
      failure_threshold     = 3
    }
  }

  application_modules = {
    wordpress = local.wordpress_module
  }

  module_env_vars = {
    WORDPRESS_DB_NAME = local.database_name_full
    WORDPRESS_DB_USER = local.database_user_full
  }

  module_secret_env_vars = {
    WORDPRESS_DB_PASSWORD = try(google_secret_manager_secret.db_password[0].secret_id, "")
  }

  module_storage_buckets = [
    {
      name_suffix   = "wp-uploads"
      location      = var.deployment_region
      force_destroy = true
    }
  ]
}
