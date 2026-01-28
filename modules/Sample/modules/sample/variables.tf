# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  sample_module = {
    app_name        = "sample-app"
    description     = "Sample Custom Application - Flask App with Database Connection"
    container_image = "python:3.11-slim" # Placeholder, actual image is built via custom build
    app_version     = "v1.0.0"
    image_source    = "build"

    # Custom build configuration
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "."
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
}

output "sample_module" {
  description = "sample application module configuration"
  value       = local.sample_module
}
