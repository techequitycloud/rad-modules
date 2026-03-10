locals {
  cyclos_module = {
    app_name            = "cyclos"
    application_version = var.application_version
    display_name        = "Cyclos Community Edition"
    description         = "Cyclos Banking System on Cloud Run"
    container_image     = "cyclos/cyclos"

    # image_source    = "build"
    image_source    = "prebuilt"
    enable_image_mirroring = true

    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "."
      dockerfile_content = null
      build_args         = {
        APP_VERSION = var.application_version
      }
      artifact_repo_name = null
    }
    container_port  = 8080
    database_type   = "POSTGRES_15"
    db_name         = "cyclos"
    db_user         = "cyclos"
    # Cyclos uses PGSimpleDataSource with TCP connection (via private IP)
    # Cloud SQL sidecar is not needed when using VPC connector
    enable_cloudsql_volume     = false
    cloudsql_volume_mount_path = "/cloudsql"
    gcs_volumes = []

    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }

    min_instance_count = 1
    max_instance_count = 1

    environment_variables = {
      DB_HOST                             = "/var/run/postgresql"
      DB_PORT                             = "5432"
      CYCLOS_HOME                         = "/usr/local/cyclos"
      "cyclos.storedFileContentManager"            = "gcs"
      "cyclos.storedFileContentManager.bucketName" = "${var.tenant_deployment_id}-cyclos-storage"
    }

    # ✅ Enable PostgreSQL extensions
    enable_postgres_extensions = true
    postgres_extensions = [
      "pg_trgm",
      "uuid-ossp",
      "cube",           # Required by earthdistance
      "earthdistance",
      "postgis",
      "unaccent"
    ]

    initialization_jobs = [
      # ===================================================================
      # JOB 1: Create PostgreSQL Extensions (as postgres/root user)
      # ===================================================================
      {
        name            = "create-extensions"
        description     = "Create required PostgreSQL extensions"
        image           = "alpine:3.19"
        script_path       = "${path.module}/scripts/cyclos/create-extensions.sh"
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
        cpu_limit         = "1000m"
        memory_limit      = "512Mi"
        timeout_seconds   = 300
        max_retries       = 2
      },

      # ===================================================================
      # JOB 2: Create Cyclos User and Grant Permissions
      # ===================================================================
      {
        name            = "create-user"
        description     = "Create Cyclos database user and grant permissions"
        image           = "alpine:3.19"
        script_path       = "${path.module}/scripts/cyclos/create-user.sh"
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
        cpu_limit         = "1000m"
        memory_limit      = "512Mi"
        timeout_seconds   = 300
        max_retries       = 2
      }
    ]

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 90  # Increased to allow schema creation
      timeout_seconds       = 30
      period_seconds        = 60
      failure_threshold     = 5   # Increased tolerance
    }

    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/api"
      initial_delay_seconds = 120  # Increased
      timeout_seconds       = 10
      period_seconds        = 60
      failure_threshold     = 3
    }
  }

  # Aggregate all modules into a single map for easy lookup
  application_modules = {
    cyclos = local.cyclos_module
  }

  # Cyclos uses PGSimpleDataSource with explicit portNumber=5432 in cyclos.properties
  # This requires TCP connection (IP address), not Unix sockets.
  # The Cloud SQL Auth Proxy sidecar is not needed when using private IP via VPC connector.
  module_env_vars = {
    DB_HOST = local.db_internal_ip
  }

  module_secret_env_vars = {}

  module_storage_buckets = [
    {
      name_suffix              = "cyclos-storage"
      location                 = var.deployment_region
      storage_class            = "STANDARD"
      force_destroy            = true
      versioning_enabled       = false
      public_access_prevention = "enforced"
    }
  ]
}
