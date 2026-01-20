# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  n8n_module = {
    app_name        = "n8n"
    description     = "n8n Workflow Automation - Workflow automation platform"
    container_image = "n8nio/n8n:latest"
    application_version = "latest"
    image_source    = "prebuilt"
    container_port  = 5678
    database_type   = "POSTGRES_15"
    db_name         = "n8n_db"
    db_user         = "n8n_user"
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"
    gcs_volumes = [{
      bucket     = "$${tenant_id}-n8n-data"
      mount_path = "/home/node/.n8n"
      read_only  = false
    }]
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "2Gi"
    }
    min_instance_count = 1
    max_instance_count = 1
    environment_variables = {
      DB_TYPE                          = "postgresdb"
      DB_POSTGRESDB_PORT               = "5432"
      N8N_USER_MANAGEMENT_DISABLED     = "false"
      EXECUTIONS_DATA_SAVE_ON_ERROR    = "all"
      EXECUTIONS_DATA_SAVE_ON_SUCCESS  = "all"
      GENERIC_TIMEZONE                 = "America/New_York"
      TZ                               = "America/New_York"
    }
    enable_postgres_extensions = false
    postgres_extensions         = []

    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 10
      timeout_seconds       = 3
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

output "n8n_module" {
  description = "n8n application module configuration"
  value       = local.n8n_module
}
