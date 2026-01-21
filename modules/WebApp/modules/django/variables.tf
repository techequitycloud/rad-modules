# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  django_module = {
    app_name        = "django"
    description     = "Django Web Application - High-level Python web framework"
    container_image = "python:3.11-slim"
    app_version     = "latest"
    image_source    = "custom"
    container_port  = 8000
    database_type   = "POSTGRES_15"
    db_name         = "django"
    db_user         = "django"
    db_tier         = "db-f1-micro"
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"
    gcs_volumes = [
      {
        bucket     = "$${tenant_id}-django-static"
        mount_path = "/app/static"
        read_only  = false
      },
      {
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
      DJANGO_SETTINGS_MODULE    = "myproject.settings.production"
      DEBUG                     = "False"
      ALLOWED_HOSTS             = "*.run.app"
      DB_ENGINE                 = "django.db.backends.postgresql"
      DB_PORT                   = "5432"
      STATIC_ROOT               = "/app/static"
      MEDIA_ROOT                = "/app/media"
      DJANGO_SUPERUSER_EMAIL    = "admin@example.com"
      DJANGO_SUPERUSER_USERNAME = "admin"
    }
    enable_postgres_extensions = true
    postgres_extensions         = ["pg_trgm", "unaccent", "hstore", "citext"]

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 30
      timeout_seconds       = 5
      period_seconds        = 10
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
  }
}

output "django_module" {
  description = "django application module configuration"
  value       = local.django_module
}
