# Simple Web Application Example
# This example deploys a basic web application using a pre-built container image

# Project Configuration
existing_project_id  = "my-gcp-project-id"
tenant_deployment_id = "prod"
deployment_region    = "us-central1"

# Application Configuration
application_name        = "myapp"
application_version     = "1.0.0"
application_description = "Simple web application"

# Container Configuration
container_image_source = "prebuilt"
container_image        = "nginx:latest"
container_port         = 80
container_protocol     = "http1"

# Database Configuration
database_type             = "MYSQL"
application_database_name = "myapp"
application_database_user = "myapp"

# Network Configuration
network_name       = "vpc-network"
vpc_egress_setting = "PRIVATE_RANGES_ONLY"
ingress_settings   = "all"

# Resource Configuration
container_resources = {
  cpu_limit    = "1000m"
  memory_limit = "512Mi"
}

# Scaling Configuration
min_instance_count = 0
max_instance_count = 5

# Storage Configuration
create_cloud_storage = true
storage_buckets = [
  {
    name_suffix = "data"
    location    = "US"
  }
]

# NFS Configuration
nfs_enabled    = true
nfs_mount_path = "/data"

# Environment Variables
environment_variables = {
  APP_ENV   = "production"
  LOG_LEVEL = "info"
}

# Health Checks
health_check_config = {
  enabled               = true
  path                  = "/"
  timeout_seconds       = 1
  period_seconds        = 10
  failure_threshold     = 3
}

startup_probe_config = {
  enabled               = true
  path                  = "/"
  timeout_seconds       = 240
}

# Monitoring
configure_monitoring = true
trusted_users        = ["admin@example.com"]

uptime_check_config = {
  enabled        = true
  path           = "/"
  check_interval = "60s"
}
