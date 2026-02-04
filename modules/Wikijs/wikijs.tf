locals {
  wikijs_module = {
    app_name                = "wikijs"
    display_name            = "Wiki.js"
    description             = "Wiki.js - The most powerful and extensible open source Wiki software"
    container_image         = "requarks/wiki"
    enable_image_mirroring  = true
    application_version     = var.application_version

    # Image source
    image_source    = "prebuilt"
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "wikijs"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = null
    }

    container_port  = 3000
    database_type   = "POSTGRES_15"
    db_name         = "wikijs"
    db_user         = "wikijs"

    # Performance optimization
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    # Storage volumes
    gcs_volumes = [{
      name       = "wikijs-storage"
      mount_path = "/wiki-storage"
      read_only  = false
      mount_options = [
        "implicit-dirs",
        "metadata-cache-ttl-secs=60",
        "file-mode=770",
        "dir-mode=770",
        "uid=1000",
        "gid=1000"
      ]
    }]

    # Resource limits
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "2Gi"
    }
    min_instance_count = 0
    max_instance_count = 3

    # Environment variables
    environment_variables = {
      DB_TYPE         = "postgres"
      DB_PORT         = "5432"
      DB_USER         = "wikijs"
      DB_NAME         = "wikijs"
      DB_SSL          = "false"
      HA_STORAGE_PATH = "/wiki-storage"
      # DB_PASS injected via secrets in main.tf
    }

    # PostgreSQL extensions
    enable_postgres_extensions = true
    postgres_extensions        = ["pg_trgm"]

    # Initialization Jobs
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create Wiki.js Database and User"
        image           = "alpine:3.19"
        script_path       = "${path.module}/scripts/wikijs/db-init.sh"
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
      }
    ]

    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/healthz"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 10
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/healthz"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
  }

  application_modules = {
    wikijs = local.wikijs_module
  }

  # Wikijs uses local Redis if NFS is enabled
  module_env_vars = {
    DB_HOST    = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    REDIS_HOST = local.nfs_server_exists ? local.nfs_internal_ip : ""
    REDIS_PORT = local.nfs_server_exists ? "6379" : ""
  }

  module_secret_env_vars = {
    DB_PASS = try(google_secret_manager_secret.db_password[0].secret_id, "")
  }

  module_storage_buckets = [
    {
      name_suffix              = "wikijs-storage"
      location                 = var.deployment_region
      storage_class            = "STANDARD"
      force_destroy            = true
      versioning_enabled       = false
      lifecycle_rules          = []
      public_access_prevention = "inherited"
    }
  ]
}
