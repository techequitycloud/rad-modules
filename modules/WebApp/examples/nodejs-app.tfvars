# Node.js Application Example
# Deploys a Node.js/Express application with PostgreSQL

# Project Configuration
existing_project_id  = "my-gcp-project-id"
tenant_deployment_id = "staging"
deployment_region    = "europe-west1"

# Application Configuration
application_name        = "nodejs-api"
application_version     = "1.2.3"
application_description = "Node.js REST API"

# Container Configuration
container_image_source = "prebuilt"
container_image        = "gcr.io/my-project/nodejs-api:1.2.3"
container_port         = 3000
container_protocol     = "http1"

# Database Configuration
database_type             = "POSTGRES_15"
application_database_name = "nodeapi"
application_database_user = "nodeapi"

# Resource Configuration
container_resources = {
  cpu_limit    = "1000m"
  memory_limit = "1Gi"
}

# Scaling Configuration
min_instance_count = 0  # Scale to zero when not in use
max_instance_count = 10

# Storage Configuration
storage_buckets = [
  {
    name_suffix = "uploads"
    location    = "EU"
  },
  {
    name_suffix = "exports"
    location    = "EU"
  }
]

gcs_volumes = [
  {
    name       = "uploads"
    mount_path = "/app/uploads"
    readonly   = false
  }
]

# NFS Configuration
nfs_enabled    = true
nfs_mount_path = "/app/shared"

# Initialization Jobs
initialization_jobs = [
  {
    name             = "db-migrate"
    description      = "Run Sequelize migrations"
    command          = ["npm"]
    args             = ["run", "migrate"]
    timeout_seconds  = 300
    execute_on_apply = true
  },
  {
    name             = "seed-data"
    description      = "Seed initial data"
    command          = ["npm"]
    args             = ["run", "seed"]
    timeout_seconds  = 180
    execute_on_apply = false  # Manual execution
  }
]

# Environment Variables
environment_variables = {
  NODE_ENV          = "staging"
  LOG_LEVEL         = "debug"
  API_VERSION       = "v1"
  MAX_UPLOAD_SIZE   = "10485760"  # 10MB
  SESSION_TIMEOUT   = "3600"
}

secret_environment_variables = {
  JWT_SECRET     = "jwt-secret"
  API_KEY        = "external-api-key"
}

# Health Checks
health_check_config = {
  enabled               = true
  path                  = "/health"
  timeout_seconds       = 3
  period_seconds        = 10
  failure_threshold     = 3
}

startup_probe_config = {
  enabled               = true
  path                  = "/health"
  timeout_seconds       = 120
  period_seconds        = 30
  failure_threshold     = 4
}

# Monitoring
configure_monitoring = true
trusted_users        = ["dev-team@example.com"]

uptime_check_config = {
  enabled        = true
  path           = "/health"
  check_interval = "300s"
}
