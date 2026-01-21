# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  moodle_module = {
    app_name        = "moodle"
    description     = "Moodle LMS - Online learning and course management platform"
    container_image = "bitnami/moodle:4"
    image_source    = "prebuilt"
    container_port  = 8080
    database_type   = "MYSQL_8_0"
    db_name         = "moodle"
    db_user         = "moodle"

    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/mysqld"

    # NFS Configuration
    nfs_enabled    = true
    nfs_mount_path = "/bitnami/moodle"

    gcs_volumes = [{
      bucket     = "$${tenant_id}-moodle-data"
      mount_path = "/bitnami/moodledata"
      read_only  = false
    }]
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 0
    max_instance_count = 3
    environment_variables = {
      MOODLE_DATABASE_TYPE = "mariadb"
      MOODLE_SKIP_BOOTSTRAP = "no"
    }
    enable_mysql_plugins = false
    mysql_plugins        = []

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
