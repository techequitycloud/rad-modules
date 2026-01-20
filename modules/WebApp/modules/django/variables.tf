# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  django_module = {
    description     = "Django Web Application - High-level Python web framework"
    image_source    = "custom"
    container_image = "python:3.11-slim"
    container_port  = 8000
    database_type   = "POSTGRES_15"
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"
    gcs_volumes = [
      {
        name       = "static"
        bucket     = "$${tenant_id}-django-static"
        mount_path = "/app/static"
        read_only  = false
      },
      {
        name       = "media"
        bucket     = "$${tenant_id}-django-media"
        mount_path = "/app/media"
        read_only  = false
      }
    ]
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "2Gi"
    }
    min_instance_count = 1
    max_instance_count = 10
    environment_variables = {
      DJANGO_SETTINGS_MODULE = "myproject.settings.production"
      DEBUG                  = "False"
      ALLOWED_HOSTS          = "*.run.app"
      DB_ENGINE              = "django.db.backends.postgresql"
      DB_PORT                = "5432"
      STATIC_ROOT            = "/app/static"
      MEDIA_ROOT             = "/app/media"
    }
    enable_postgres_extensions = true
    postgres_extensions         = ["pg_trgm", "unaccent", "hstore", "citext"]

    # Health Checks
    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 0
      timeout_seconds       = 240
      period_seconds        = 240
      failure_threshold     = 1
    }
    liveness_probe = {
      enabled               = false
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 0
      timeout_seconds       = 1
      period_seconds        = 10
      failure_threshold     = 3
    }
  }
}

output "django_module" {
  description = "django application module configuration"
  value       = local.django_module
}
