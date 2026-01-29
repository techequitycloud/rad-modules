locals {
  sample_module = {
    app_name            = "sample-app"
    display_name        = "Sample Application"
    description         = "Sample Custom Application - Flask App with Database Connection"
    container_image     = "sample" # Empty for custom build to avoid double tagging
    application_version = "1.0.0"
    image_source        = "custom"
    enable_image_mirroring = false

    # Custom build configuration
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "sample"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = null
    }

    container_port  = 8080
    database_type   = "POSTGRES_15"
    db_name         = "sampledb"
    db_user         = "sampleuser"

    # Enable Cloud SQL volume for potential socket connection (though app uses TCP in this sample)
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "512Mi"
    }
    min_instance_count = 0
    max_instance_count = 1

    environment_variables = {
      FLASK_ENV = "production"
    }

    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/healthz"
      initial_delay_seconds = 10
      timeout_seconds       = 5
      period_seconds        = 10
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/healthz"
      initial_delay_seconds = 15
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }

    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Initialize Sample Database"
        image           = "postgres:15-alpine"
        command         = ["/bin/sh"]
        script_path     = "scripts/sample/db-init.sh"
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
      }
    ]
  }

  # Aggregate all modules into a single map for easy lookup
  application_modules = {
    sample = local.sample_module
  }

  module_env_vars = {
    DB_HOST = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
  }

  module_secret_env_vars = {}

  module_storage_buckets = []
}
