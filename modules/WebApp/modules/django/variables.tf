# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  django_module = {
    description     = "Django Web Application - High-level Python web framework"
    container_image = "python:3.11-slim"
    container_port  = 8000
    database_type   = "POSTGRES_15"
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    # Storage volumes
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

    # Resource limits
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "2Gi"
    }
    min_instance_count = 1
    max_instance_count = 10

    # Environment variables
    environment_variables = {
      DJANGO_SETTINGS_MODULE = "myproject.settings.production"
      DEBUG                  = "False"
      ALLOWED_HOSTS          = "*.run.app"
      DB_ENGINE              = "django.db.backends.postgresql"
      DB_PORT                = "5432"
      STATIC_ROOT            = "/app/static"
      MEDIA_ROOT             = "/app/media"
      # Default Superuser config (overridable)
      DJANGO_SUPERUSER_USERNAME = "admin"
      DJANGO_SUPERUSER_EMAIL    = "admin@example.com"
    }

    # PostgreSQL extensions
    enable_postgres_extensions = true
    postgres_extensions         = ["pg_trgm", "unaccent", "hstore", "citext"]

    # Initialization Jobs
    # Note: Superuser creation requires a secret for DJANGO_SUPERUSER_PASSWORD which must be provided by the user
    # or created manually. Automated password generation for extra secrets is not supported in the preset.
    initialization_jobs = [
      {
        name            = "migrate"
        description     = "Run database migrations and collect static files"
        command         = ["/bin/bash", "-c"]
        args            = ["python manage.py migrate && python manage.py collectstatic --noinput --clear"]
        timeout_seconds = 600
        mount_gcs_volumes = ["static"]
      }
    ]
  }
}

output "django_module" {
  description = "django application module configuration"
  value       = local.django_module
}
