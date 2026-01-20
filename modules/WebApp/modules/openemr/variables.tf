# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  openemr_module = {
    description     = "OpenEMR - Electronic health records and medical practice management"
    container_image = "openemr/openemr:7.0.2"
    container_port  = 80
    database_type   = "MYSQL_8_0"
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/mysqld"
    gcs_volumes = [{
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
  }
}

output "openemr_module" {
  description = "openemr application module configuration"
  value       = local.openemr_module
}
