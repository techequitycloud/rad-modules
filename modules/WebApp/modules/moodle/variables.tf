# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  moodle_module = {
    description     = "Moodle LMS - Online learning and course management platform"
    image_source    = "custom"
    container_image = "moodle:4.3-apache"
    container_port  = 80
    database_type   = "MYSQL_8_0"
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/mysqld"
    gcs_volumes = [{
      name       = "data"
      bucket     = "$${tenant_id}-moodle-data"
      mount_path = "/var/moodledata"
      read_only  = false
    }]
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 1
    max_instance_count = 10
    environment_variables = {
      MOODLE_DATABASE_TYPE = "mysqli"
      MOODLE_DATABASE_HOST = "/var/run/mysqld/mysqld.sock"
    }
    enable_mysql_plugins = false
    mysql_plugins        = []

    # NFS Configuration
    nfs_config = {
      enabled    = true
      mount_path = "/mnt"
    }

    # Health Checks
    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 120
      timeout_seconds       = 60
      period_seconds        = 120
      failure_threshold     = 1
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 120
      timeout_seconds       = 5
      period_seconds        = 120
      failure_threshold     = 3
    }
  }
}

output "moodle_module" {
  description = "moodle application module configuration"
  value       = local.moodle_module
}
