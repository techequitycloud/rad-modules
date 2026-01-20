# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  openemr_module = {
    description     = "OpenEMR - Electronic health records and medical practice management"
    image_source    = "prebuilt"
    container_image = "openemr/openemr:7.0.2"
    container_port  = 80
    database_type   = "MYSQL_8_0"
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/mysqld"
    gcs_volumes = [{
      name       = "data"
      bucket     = "$${tenant_id}-openemr-sites"
      mount_path = "/var/www/localhost/htdocs/openemr/sites"
      read_only  = false
    }]
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 1
    max_instance_count = 10
    environment_variables = {
      MYSQL_HOST = "localhost:/var/run/mysqld/mysqld.sock"
    }
    enable_mysql_plugins = false
    mysql_plugins        = []

    # NFS Configuration
    nfs_config = {
      enabled    = true
      mount_path = "/var/www/localhost/htdocs/openemr/sites"
    }

    # Health Checks
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
