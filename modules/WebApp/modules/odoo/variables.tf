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
    db_name         = "odoo"
    db_user         = "odoo"

    # Performance optimization
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/postgresql"

    # NFS Configuration
    nfs_enabled    = true
    nfs_mount_path = "/mnt"

    # Storage volumes (Addons)
    gcs_volumes = [{
      name       = "odoo-addons-volume"
      bucket     = "$${tenant_id}-odoo-addons"
      mount_path = "/extra-addons"
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

    # Initialization Jobs
    initialization_jobs = [
      {
        name            = "nfs-init"
        description     = "Initialize NFS directories for Odoo"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          "mkdir -p /mnt/filestore /mnt/sessions /mnt/addons /mnt/backups && chmod 777 /mnt/filestore /mnt/sessions /mnt/addons /mnt/backups"
        ]
        mount_nfs       = true
      },
      {
        name            = "odoo-init"
        description     = "Initialize Odoo database"
        image           = null # Uses default container image (odoo)
        command         = ["/bin/bash", "-c"]
        args            = [
          "odoo -d $DB_NAME --db_host=$DB_HOST --db_port=$DB_PORT --db_user=$DB_USER --db_password=$DB_PASSWORD --data-dir=/mnt/filestore --addons-path=/usr/lib/python3/dist-packages/odoo/addons,/extra-addons -i base --stop-after-init --log-level=info"
        ]
        mount_nfs         = true
        mount_gcs_volumes = ["odoo-addons-volume"]
      }
    ]

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
