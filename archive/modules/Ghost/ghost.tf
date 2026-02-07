locals {
  ghost_module = {
    app_name            = "ghost"
    description         = "Ghost - Professional publishing platform"
    container_image     = "ghost" 
    application_version = var.application_version
    enable_image_mirroring = false

    # Use custom build to avoid Docker Hub pull restrictions in Cloud Build
    image_source = "custom"

    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "ghost"
      dockerfile_content = null
      build_args = {
        APP_VERSION = var.application_version
      }
      artifact_repo_name = null
    }

    container_port  = 2368
    database_type   = "MYSQL_8_0"  # Ghost 6.x requires MySQL 8.0+
    db_name         = "ghost"
    db_user         = "ghost"

    # ✅ Enable CloudSQL volume for better performance
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    # Storage volumes for Ghost content
    gcs_volumes = [{
      name       = "ghost-content"
      mount_path = "/var/lib/ghost/content"
      read_only  = false
      mount_options = [
        "implicit-dirs",
        "uid=1000",      # Ghost user
        "gid=1000",      # Ghost group
        "dir-mode=755",
        "file-mode=644"
      ]
    }]

    # ✅ Updated resource limits for Ghost 6.x (requires more memory)
    container_resources = {
      cpu_limit    = "2000m"      # Increased from 1000m
      memory_limit = "4Gi"        # Increased from 2Gi (Ghost 6.x is more resource-intensive)
    }
    min_instance_count = 0
    max_instance_count = 5        # Increased for better scaling

    # ✅ Environment variables for Ghost 6.10.3
    environment_variables = {
      # Node Environment
      NODE_ENV = "production"

      # Ghost 6.x Configuration
      logging__transports = "[\"stdout\"]"
      logging__level = "info"

      # ✅ Privacy settings (new in Ghost 6.x)
      privacy__useUpdateCheck = "false"
      privacy__useGravatar = "true"
      privacy__useRpcPing = "false"

      # ✅ Database Connection via Unix Socket (faster)
      database__client = "mysql"
      # Host will be overridden in module_env_vars
      database__connection__port = "3306"
      # User/DB will be overridden in module_env_vars

      # ✅ Connection pool settings (optimized for Ghost 6.x)
      database__pool__min = "2"
      database__pool__max = "20"  # Increased from 10
      database__connection__charset = "utf8mb4"

      # ✅ Ghost 6.x performance settings
      database__useNullAsDefault = "false"

      # ✅ Content API settings
      admin__url = ""  # Will be set in main.tf (module_env_vars)

      # ✅ Caching (new in Ghost 6.x)
      caching__frontend__maxAge = "600"
      caching__301__maxAge = "31536000"

      # ✅ Image optimization
      imageOptimization__resize = "true"
      imageOptimization__contentImageSizes = "w=600,w=1000,w=1600,w=2400"
    }

    # ✅ Database password via secrets
    secret_environment_variables = {
      # This is redundant as we inject it via module_secret_env_vars, but keeping it as per preset
      database__connection__password = "ghost-db-password"
    }

    # MySQL plugins (not needed for Ghost)
    enable_mysql_plugins = false
    mysql_plugins        = []

    # ✅ Updated Initialization Jobs for Ghost 6.10.3
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Initialize Ghost 6.10.3 Database with MySQL 8.0 settings"
        image           = "mysql:8.0-debian"  # ✅ Updated to use MySQL 8.0 image
        script_path       = "${path.module}/scripts/ghost/db-init.sh"
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
        timeout_seconds   = 300
        max_retries       = 1
        depends_on_jobs   = []

        env_vars = {}
        secret_env_vars = {}
      }
    ]

    # ✅ Updated health checks for Ghost 6.x
    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"  # ✅ Ghost 6.x API endpoint
      initial_delay_seconds = 90   # Ghost 6.x takes longer to start
      timeout_seconds       = 10
      period_seconds        = 10
      failure_threshold     = 10   # More lenient for initial startup
    }

    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }

    # ✅ Readiness probe (new)
    readiness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 30
      timeout_seconds       = 5
      period_seconds        = 10
      failure_threshold     = 3
    }
  }

  application_modules = {
    ghost = local.ghost_module
  }

  module_env_vars = {
    url                            = local.predicted_service_url
    database__connection__host     = local.db_internal_ip
    database__connection__user     = local.database_user_full
    database__connection__database = local.database_name_full
    database__connection__port     = "3306"
    database__connection__socketPath = ""
  }

  module_secret_env_vars = {
    database__connection__password = try(google_secret_manager_secret.db_password[0].secret_id, "")
  }

  module_storage_buckets = [
    {
      name_suffix              = "ghost-content"
      location                 = var.deployment_region
      storage_class            = "STANDARD"
      force_destroy            = true
      versioning_enabled       = false
      lifecycle_rules          = []
      public_access_prevention = "inherited"
    }
  ]
}
