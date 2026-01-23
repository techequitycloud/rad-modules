# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

#########################################################################
# Sanity CMS Preset Configuration
#########################################################################

locals {
  sanity_module = {
    app_name        = "sanity-studio"
    description     = "Sanity Studio - Open Source Content Platform"
    # Sanity requires a custom built image.
    container_image = ""
    image_source    = "custom"

    # Custom build configuration
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "sanity"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = "webapp-repo"
    }

    container_port  = 8080
    database_type   = "NONE"

    # Database is not used but these keys might be required to avoid null errors if checked blindly
    db_name         = "sanity"
    db_user         = "sanity"

    enable_cloudsql_volume     = false
    cloudsql_volume_mount_path = ""

    # Storage volumes (Sanity uses hosted content lake)
    gcs_volumes = []

    # Resource limits
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "512Mi"
    }
    min_instance_count = 1
    max_instance_count = 3

    # Environment variables
    environment_variables = {
      NODE_ENV               = "production"
      SANITY_STUDIO_PROJECT_ID = ""
      SANITY_STUDIO_DATASET    = "production"
    }

    # Initialization Jobs
    initialization_jobs = []

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 10
      timeout_seconds       = 5
      period_seconds        = 10
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 30
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
  }
}

output "sanity_module" {
  description = "sanity application module configuration"
  value       = local.sanity_module
}
