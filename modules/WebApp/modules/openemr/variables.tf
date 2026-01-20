# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  openemr_module = {
    app_name        = "openemr"
    description     = "OpenEMR - Electronic health records and medical practice management"
    container_image = "openemr/openemr:7.0.3"
    image_source    = "prebuilt"
    container_port  = 80
    database_type   = "MYSQL_8_0"
    db_name         = "openemr"
    db_user         = "openemr"

    # Backup Configuration
    enable_backup_import = true
    backup_source        = "gdrive"
    backup_uri           = "1nitol1S9hdcjf7PpHvsRl3ZDwhKYlzF2"

    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/mysqld"

    # NFS Configuration (Preferred for OpenEMR sites folder due to file locking)
    nfs_enabled    = true
    nfs_mount_path = "/var/www/localhost/htdocs/openemr/sites"

    # Note: GCS volume removed in favor of NFS for sites directory to match proven WebApp preset
    gcs_volumes = []

    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 1
    max_instance_count = 1
    environment_variables = {
      MYSQL_HOST = "localhost:/var/run/mysqld/mysqld.sock"
      MYSQL_PORT = "3306"
      OE_USER    = "admin"
      OE_PASS    = "admin"
      MANUAL_SETUP = "no"
    }
    enable_mysql_plugins = false
    mysql_plugins        = []

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 240
      timeout_seconds       = 60
      period_seconds        = 240
      failure_threshold     = 5
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/interface/login/login.php"
      initial_delay_seconds = 300
      timeout_seconds       = 60
      period_seconds        = 60
      failure_threshold     = 3
    }
  }
}

output "openemr_module" {
  description = "openemr application module configuration"
  value       = local.openemr_module
}
