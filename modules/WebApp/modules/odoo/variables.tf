# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

#########################################################################
# Odoo ERP Preset Configuration
#########################################################################

locals {
  odoo_module = {
    app_name        = "odoo"
    description     = "Odoo ERP System - CRM, e-commerce, billing, accounting, manufacturing, warehouse, project management"
    container_image = "odoo:18.0"
    image_source    = "prebuilt"
    container_port  = 8069
    database_type   = "POSTGRES_15"
    db_name         = "odoo_db"
    db_user         = "odoo_user"

    # Performance optimization
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/postgresql"

    # NFS Configuration
    nfs_enabled    = true
    nfs_mount_path = "/mnt"

    # Storage volumes
    gcs_volumes = [{
      bucket     = "$${tenant_id}-odoo-filestore"
      mount_path = "/var/lib/odoo/filestore"
      read_only  = false
    }]

    # Resource limits
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 1
    max_instance_count = 1

    # Environment variables
    environment_variables = {
      DB_HOST = "/var/run/postgresql"
      DB_PORT = "5432"
    }

    # PostgreSQL extensions
    enable_postgres_extensions = false
    postgres_extensions         = []

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 180
      timeout_seconds       = 60
      period_seconds        = 120
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/web/health"
      initial_delay_seconds = 120
      timeout_seconds       = 60
      period_seconds        = 120
      failure_threshold     = 3
    }
  }
}

output "odoo_module" {
  description = "odoo application module configuration"
  value       = local.odoo_module
}
