# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  n8n_module = {
    description     = "n8n Workflow Automation - Workflow automation platform"
    container_image = "n8nio/n8n:latest"
    container_port  = 5678
    database_type   = "POSTGRES_15"
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"
    gcs_volumes = [{
      bucket     = "$${tenant_id}-n8n-data"
      mount_path = "/home/node/.n8n"
      read_only  = false
    }]
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 1
    max_instance_count = 10
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
  }
}

output "n8n_module" {
  description = "n8n application module configuration"
  value       = local.n8n_module
}
