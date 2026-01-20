# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  nextcloud_module = {
    app_name        = "nextcloud"
    description     = "Nextcloud File Sync and Share - Self-hosted collaboration platform"
    container_image = "nextcloud:28-apache"
    image_source    = "prebuilt"
    container_port  = 80
    database_type   = "POSTGRES_15"
    db_name         = "nextcloud_db"
    db_user         = "nextcloud_user"

    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/postgresql"

    gcs_volumes = [
      {
        bucket     = "$${tenant_id}-nextcloud-data"
        mount_path = "/var/www/html/data"
        read_only  = false
      },
      {
        bucket     = "$${tenant_id}-nextcloud-config"
        mount_path = "/var/www/html/config"
        read_only  = false
      }
    ]
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 1
    max_instance_count = 10
    environment_variables = {
      POSTGRES_HOST = "/var/run/postgresql"
    }
    enable_postgres_extensions = false
    postgres_extensions         = []

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
      path                  = "/status.php"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 60
      failure_threshold     = 3
    }
  }
}

output "nextcloud_module" {
  description = "nextcloud application module configuration"
  value       = local.nextcloud_module
}
