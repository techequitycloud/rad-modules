# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  cyclos_module = {
    app_name        = "cyclos"
    description     = "Cyclos Banking System - Online banking for financial institutions"
    container_image = "cyclos/cyclos:4.16.15"
    image_source    = "prebuilt"
    container_port  = 8080
    database_type   = "POSTGRES_15"
    db_name         = "cyclos_db"
    db_user         = "cyclos_user"
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/postgresql"
    gcs_volumes = [{
      bucket     = "$${tenant_id}-cyclos-data"
      mount_path = "/usr/local/cyclos/data"
      read_only  = false
    }]
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 1
    max_instance_count = 1
    environment_variables = {
      DB_HOST     = "/var/run/postgresql"
      DB_PORT     = "5432"
      CYCLOS_HOME = "/usr/local/cyclos"
    }
    enable_postgres_extensions = true
    postgres_extensions         = ["pg_trgm", "uuid-ossp"]

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 60
      timeout_seconds       = 30
      period_seconds        = 60
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/api"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 60
      failure_threshold     = 3
    }
  }
}

output "cyclos_module" {
  description = "cyclos application module configuration"
  value       = local.cyclos_module
}
