# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  budibase_module = {
    app_name            = "budibase"
    description         = "Budibase - Open source low-code platform"
    container_image     = "budibase/budibase:latest"
    application_version = "latest"
    image_source        = "prebuilt"
    container_port      = 80

    # Budibase AIO uses embedded databases, so we use NFS for persistence
    nfs_enabled    = true
    nfs_mount_path = "/data"

    # We do not use Cloud SQL for this AIO deployment
    enable_cloudsql_volume = false

    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }

    min_instance_count = 1
    max_instance_count = 1

    environment_variables = {
      PORT        = "80"
      SELF_HOSTED = "1"
      # COUCHDB_USER will be injected via main.tf along with secrets
    }

    initialization_jobs = []

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/" # Ignored for TCP
      initial_delay_seconds = 10
      timeout_seconds       = 5
      period_seconds        = 10
      failure_threshold     = 5
    }

    liveness_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/" # Ignored for TCP
      initial_delay_seconds = 30
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
  }
}

output "budibase_module" {
  description = "Budibase application module configuration"
  value       = local.budibase_module
}
