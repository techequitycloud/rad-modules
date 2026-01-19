# Advanced Web Application Example
# This example demonstrates custom container build, initialization jobs, and advanced features

# Project Configuration
existing_project_id  = "my-gcp-project-id"
tenant_deployment_id = "production"
deployment_region    = "us-central1"

# Application Configuration
application_name        = "django-app"
application_version     = "2.1.0"
application_description = "Django web application with PostgreSQL"

# Container Configuration - Custom Build
container_image_source = "custom"
container_build_config = {
  enabled = true
  # dockerfile_content would be provided in the actual module call
  # dockerfile_content = file("${path.module}/Dockerfile")
  dockerfile_path    = "Dockerfile"
  context_path       = "."
  build_args = {
    PYTHON_VERSION = "3.11"
    APP_ENV        = "production"
  }
  artifact_repo_name = "django-repo"
}

container_port     = 8000
container_protocol = "http1"

# Database Configuration
database_type             = "POSTGRES_14"
application_database_name = "django"
application_database_user = "django"
database_password_length  = 24

# Network Configuration
network_name       = "vpc-network"
vpc_egress_setting = "PRIVATE_RANGES_ONLY"
ingress_settings   = "all"
network_tags       = ["nfsserver", "webapp"]

# Resource Configuration
container_resources = {
  cpu_limit    = "2000m"
  memory_limit = "4Gi"
}

container_concurrency = 100
timeout_seconds       = 300

# Scaling Configuration
min_instance_count = 1  # Keep 1 instance warm
max_instance_count = 20
max_instance_request_concurrency = 100

# Storage Configuration
create_cloud_storage = true
storage_buckets = [
  {
    name_suffix        = "media"
    location           = "US"
    storage_class      = "STANDARD"
    versioning_enabled = true
    lifecycle_rules = [
      {
        action = {
          type = "Delete"
        }
        condition = {
          age = 365
          with_state = "ARCHIVED"
        }
      }
    ]
  },
  {
    name_suffix   = "static"
    location      = "US"
    storage_class = "STANDARD"
  },
  {
    name_suffix   = "backups"
    location      = "US"
    storage_class = "NEARLINE"
  }
]

# NFS Configuration
nfs_enabled    = true
nfs_mount_path = "/app/shared"

# GCS Volume Mounts
gcs_volumes = [
  {
    name        = "media"
    bucket_name = null  # Will use auto-created bucket
    mount_path  = "/app/media"
    readonly    = false
    mount_options = [
      "implicit-dirs",
      "stat-cache-ttl=60s",
      "type-cache-ttl=60s",
      "uid=1000",
      "gid=1000",
      "file-mode=644",
      "dir-mode=755"
    ]
  },
  {
    name        = "static"
    bucket_name = null
    mount_path  = "/app/static"
    readonly    = true
  }
]

# Initialization Jobs
initialization_jobs = [
  {
    name             = "migrate-db"
    description      = "Run Django database migrations"
    command          = ["python"]
    args             = ["manage.py", "migrate", "--noinput"]
    cpu_limit        = "1000m"
    memory_limit     = "2Gi"
    timeout_seconds  = 600
    max_retries      = 2
    execute_on_apply = true
    env_vars = {
      DJANGO_SETTINGS_MODULE = "myapp.settings.production"
    }
  },
  {
    name             = "collectstatic"
    description      = "Collect Django static files"
    command          = ["python"]
    args             = ["manage.py", "collectstatic", "--noinput"]
    cpu_limit        = "1000m"
    memory_limit     = "1Gi"
    timeout_seconds  = 300
    execute_on_apply = true
    mount_gcs_volumes = ["static"]
    env_vars = {
      DJANGO_SETTINGS_MODULE = "myapp.settings.production"
    }
  },
  {
    name             = "create-superuser"
    description      = "Create Django superuser"
    command          = ["python"]
    args = [
      "manage.py",
      "shell",
      "-c",
      "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@example.com', 'changeme') if not User.objects.filter(username='admin').exists() else None"
    ]
    timeout_seconds  = 120
    execute_on_apply = true
  }
]

# Environment Variables
environment_variables = {
  DJANGO_SETTINGS_MODULE = "myapp.settings.production"
  DEBUG                  = "False"
  ALLOWED_HOSTS          = "*"
  SECURE_SSL_REDIRECT    = "True"
  SESSION_COOKIE_SECURE  = "True"
  CSRF_COOKIE_SECURE     = "True"
}

# Secret Environment Variables (must exist in Secret Manager)
secret_environment_variables = {
  SECRET_KEY     = "django-secret-key"
  EMAIL_PASSWORD = "email-password"
  AWS_SECRET_KEY = "aws-secret-key"
}

# Health Checks
health_check_config = {
  enabled               = true
  path                  = "/health/"
  initial_delay_seconds = 30
  timeout_seconds       = 5
  period_seconds        = 10
  failure_threshold     = 3
}

startup_probe_config = {
  enabled               = true
  path                  = "/health/"
  initial_delay_seconds = 60
  timeout_seconds       = 300
  period_seconds        = 60
  failure_threshold     = 3
}

# Monitoring and Alerting
configure_monitoring = true
trusted_users        = ["devops@example.com", "oncall@example.com"]

uptime_check_config = {
  enabled        = true
  path           = "/health/"
  check_interval = "60s"
  timeout        = "10s"
}

alert_policies = [
  {
    name               = "high-error-rate"
    metric_type        = "run.googleapis.com/request_count"
    comparison         = "COMPARISON_GT"
    threshold_value    = 100
    duration_seconds   = 300
    aggregation_period = "60s"
  },
  {
    name               = "high-latency"
    metric_type        = "run.googleapis.com/request_latencies"
    comparison         = "COMPARISON_GT"
    threshold_value    = 5000  # 5 seconds
    duration_seconds   = 180
    aggregation_period = "60s"
  }
]

# Feature Flags
configure_environment = true
enable_custom_domain  = false
enable_cdn            = false
enable_iap            = false

# Execution Environment
execution_environment = "gen2"

# Service Labels and Annotations
service_labels = {
  team        = "backend"
  environment = "production"
  cost-center = "engineering"
}

resource_labels = {
  managed-by  = "terraform"
  application = "django-app"
  team        = "backend"
}
