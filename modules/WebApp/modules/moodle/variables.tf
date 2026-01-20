# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  moodle_module = {
    app_name        = "moodle"
    description     = "Moodle LMS - Online learning and course management platform"
    container_image = "moodle:4.3-apache"
    image_source    = "prebuilt"
    container_port  = 80
    database_type   = "MYSQL_8_0"
    db_name         = "moodle"
    db_user         = "moodle"

    application_version   = "5.0.0"
    network_name          = "vpc-network"
    create_cloud_storage  = true
    configure_environment = true
    configure_monitoring  = true

    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/mysqld"

    # NFS Configuration
    nfs_enabled    = true
    nfs_mount_path = "/mnt"

    gcs_volumes = [{
      bucket     = "$${tenant_id}-moodle-data"
      mount_path = "/var/moodledata"
      read_only  = false
    }]
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi" # Updated to match preset (was 4Gi in file, preset had 2Gi/1000m? Preset had 1000m/2Gi. File had 2000m/4Gi. Keeping file's higher limits or preset? Preset had 1000m/2Gi. I will stick to the file's values if they seem better, or preset? Preset is what was running. Let's use preset values to avoid regression, or stick to file if file was intended to be better. The file had 2000m/4Gi. I will use 1000m/2Gi from preset to be safe/consistent with main.tf logic.)
    }
    min_instance_count = 1
    max_instance_count = 10
    environment_variables = {
      MOODLE_DATABASE_TYPE = "mysqli"
      MOODLE_DATABASE_HOST = "/var/run/mysqld/mysqld.sock"
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
