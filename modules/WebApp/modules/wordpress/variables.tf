# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

#########################################################################
# WordPress CMS Preset Configuration
#########################################################################

locals {
  wordpress_module = {
    app_name        = "wp"
    description     = "WordPress CMS - Popular content management system for websites and blogs"
    container_image = "wordpress:6.8.1-apache"
    image_source    = "prebuilt"
    container_port  = 80
    database_type   = "MYSQL_8_0"
    db_name         = "wp"
    db_user         = "wp"
    application_version = "6.8.1"
    application_sha     = "52d5f05c96a9155f78ed84700264307e5dea14b4"

    # Performance optimization
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/mysqld"

    # Storage volumes
    gcs_volumes = [{
      name       = "wp-uploads"
      mount_path = "/var/www/html/wp-content"
      read_only  = false
      mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
    }]

    # Resource limits
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "2Gi"
    }
    min_instance_count = 1
    max_instance_count = 3 

    # Environment variables
    environment_variables = {
      WORDPRESS_DB_HOST      = "localhost:/var/run/mysqld/mysqld.sock"
      WORDPRESS_TABLE_PREFIX = "wp_"
      WORDPRESS_DEBUG        = "false"
    }

    # MySQL plugins
    enable_mysql_plugins = false
    mysql_plugins        = []

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 240
      timeout_seconds       = 60
      period_seconds        = 240
      failure_threshold     = 1
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/wp-admin/install.php"
      initial_delay_seconds = 300
      timeout_seconds       = 60
      period_seconds        = 60
      failure_threshold     = 3
    }
  }
}

output "wordpress_module" {
  description = "wordpress application module configuration"
  value       = local.wordpress_module
}
