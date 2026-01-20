# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

#########################################################################
# Odoo ERP Preset Configuration
#########################################################################

locals {
  odoo_preset = {
    description     = "Odoo ERP System - CRM, e-commerce, billing, accounting, manufacturing, warehouse, project management"
    container_image = "odoo:18.0"
    container_port  = 8069
    database_type   = "POSTGRES_15"

    # Performance optimization
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/postgresql"

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
    max_instance_count = 10

    # Environment variables
    environment_variables = {
      DB_HOST = "/var/run/postgresql"
      DB_PORT = "5432"
    }

    # PostgreSQL extensions
    enable_postgres_extensions = false
    postgres_extensions         = []
  }
}

output "odoo_preset" {
  description = "odoo application preset configuration"
  value       = local.odoo_preset
}
