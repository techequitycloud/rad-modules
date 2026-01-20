# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

locals {
  gitlab_module = {
    description     = "GitLab DevOps Platform - Complete DevOps platform"
    container_image = "gitlab/gitlab-ce:16.8.0-ce.0"
    container_port  = 80
    database_type   = "POSTGRES_15"
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/postgresql"
    gcs_volumes = [
      {
        bucket     = "$${tenant_id}-gitlab-data"
        mount_path = "/var/opt/gitlab"
        read_only  = false
      },
      {
        bucket     = "$${tenant_id}-gitlab-config"
        mount_path = "/etc/gitlab"
        read_only  = false
      }
    ]
    container_resources = {
      cpu_limit    = "4000m"
      memory_limit = "8Gi"
    }
    min_instance_count = 1
    max_instance_count = 5
    environment_variables = {
      GITLAB_OMNIBUS_CONFIG = "external_url 'https://gitlab.example.com'"
    }
    enable_postgres_extensions = true
    postgres_extensions         = ["pg_trgm", "btree_gist"]
  }
}

output "gitlab_module" {
  description = "gitlab application module configuration"
  value       = local.gitlab_module
}
