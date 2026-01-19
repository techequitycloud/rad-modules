# ===========================
# Project and Identity Variables
# ===========================

variable "existing_project_id" {
  description = "The GCP project ID where resources will be deployed"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.existing_project_id))
    error_message = "Project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "resource_creator_identity" {
  description = "The email of the entity creating resources (user or service account)"
  type        = string
  default     = null
}

variable "agent_service_account" {
  description = "Service account to impersonate for API calls (optional)"
  type        = string
  default     = null
}

variable "resource_labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = null
}

# ===========================
# Deployment Configuration
# ===========================

variable "deployment_id" {
  description = "Unique deployment identifier (auto-generated if not provided)"
  type        = string
  default     = null
}

variable "tenant_deployment_id" {
  description = "Tenant identifier for multi-tenant deployments"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,20}$", var.tenant_deployment_id))
    error_message = "Tenant ID must be 1-20 characters, lowercase letters, numbers, and hyphens only."
  }
}

variable "deployment_region" {
  description = "Primary deployment region"
  type        = string
  default     = "us-central1"
}

variable "deployment_regions" {
  description = "List of regions for multi-region deployment (optional)"
  type        = list(string)
  default     = []
}

# ===========================
# Application Configuration
# ===========================

variable "application_name" {
  description = "Application name (used in resource naming)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,19}$", var.application_name))
    error_message = "Application name must start with a letter, be 1-20 characters, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "application_display_name" {
  description = "Human-readable application name"
  type        = string
  default     = null
}

variable "application_version" {
  description = "Application version tag"
  type        = string
  default     = "latest"
}

variable "application_description" {
  description = "Application description"
  type        = string
  default     = ""
}

# ===========================
# Database Configuration
# ===========================

variable "database_type" {
  description = "Database type (MYSQL, POSTGRES, SQLSERVER, etc.)"
  type        = string
  default     = "MYSQL"

  validation {
    condition     = contains(["MYSQL", "POSTGRES", "POSTGRESQL", "SQLSERVER", "MYSQL_5_6", "MYSQL_5_7", "MYSQL_8_0", "POSTGRES_9_6", "POSTGRES_10", "POSTGRES_11", "POSTGRES_12", "POSTGRES_13", "POSTGRES_14", "POSTGRES_15", "SQLSERVER_2017_STANDARD", "SQLSERVER_2017_ENTERPRISE", "SQLSERVER_2019_STANDARD", "SQLSERVER_2019_ENTERPRISE"], var.database_type)
    error_message = "Database type must be a valid Cloud SQL database version."
  }
}

variable "application_database_name" {
  description = "Application database name"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.application_database_name))
    error_message = "Database name must start with a letter, be 1-63 characters, and contain only lowercase letters, numbers, and underscores."
  }
}

variable "application_database_user" {
  description = "Application database user"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,31}$", var.application_database_user))
    error_message = "Database user must start with a letter, be 1-32 characters, and contain only lowercase letters, numbers, and underscores."
  }
}

variable "database_password_length" {
  description = "Length of auto-generated database password"
  type        = number
  default     = 16

  validation {
    condition     = var.database_password_length >= 8 && var.database_password_length <= 64
    error_message = "Password length must be between 8 and 64 characters."
  }
}

variable "database_flags" {
  description = "Additional database flags (key-value pairs)"
  type        = map(string)
  default     = {}
}

# ===========================
# Container Configuration
# ===========================

variable "container_image_source" {
  description = "Container image source: 'prebuilt' or 'custom'"
  type        = string
  default     = "prebuilt"

  validation {
    condition     = contains(["prebuilt", "custom"], var.container_image_source)
    error_message = "Container image source must be 'prebuilt' or 'custom'."
  }
}

variable "container_image" {
  description = "Pre-built container image (e.g., 'nginx:latest', 'gcr.io/project/app:v1')"
  type        = string
  default     = null
}

variable "container_port" {
  description = "Container port to expose"
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port > 0 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "container_protocol" {
  description = "Container protocol (http1 or h2c)"
  type        = string
  default     = "http1"

  validation {
    condition     = contains(["http1", "h2c"], var.container_protocol)
    error_message = "Container protocol must be 'http1' or 'h2c'."
  }
}

# Custom container build configuration
variable "container_build_config" {
  description = "Custom container build configuration"
  type = object({
    enabled            = bool
    dockerfile_path    = optional(string, "Dockerfile")
    dockerfile_content = optional(string, null)
    context_path       = optional(string, ".")
    build_args         = optional(map(string), {})
    artifact_repo_name = optional(string, "webapp-repo")
  })
  default = {
    enabled = false
  }
}

# ===========================
# Resource Configuration
# ===========================

variable "container_resources" {
  description = "Container resource limits"
  type = object({
    cpu_limit    = string
    memory_limit = string
    cpu_request  = optional(string, null)
    mem_request  = optional(string, null)
  })
  default = {
    cpu_limit    = "1000m"
    memory_limit = "512Mi"
  }
}

variable "container_concurrency" {
  description = "Maximum concurrent requests per container"
  type        = number
  default     = 80

  validation {
    condition     = var.container_concurrency >= 0 && var.container_concurrency <= 1000
    error_message = "Container concurrency must be between 0 and 1000."
  }
}

variable "timeout_seconds" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300

  validation {
    condition     = var.timeout_seconds >= 0 && var.timeout_seconds <= 3600
    error_message = "Timeout must be between 0 and 3600 seconds."
  }
}

# ===========================
# Scaling Configuration
# ===========================

variable "min_instance_count" {
  description = "Minimum number of container instances"
  type        = number
  default     = 0

  validation {
    condition     = var.min_instance_count >= 0 && var.min_instance_count <= 1000
    error_message = "Minimum instance count must be between 0 and 1000."
  }
}

variable "max_instance_count" {
  description = "Maximum number of container instances"
  type        = number
  default     = 3

  validation {
    condition     = var.max_instance_count >= 1 && var.max_instance_count <= 1000
    error_message = "Maximum instance count must be between 1 and 1000."
  }
}

variable "max_instance_request_concurrency" {
  description = "Maximum concurrent requests per instance"
  type        = number
  default     = 80

  validation {
    condition     = var.max_instance_request_concurrency >= 1 && var.max_instance_request_concurrency <= 1000
    error_message = "Max instance request concurrency must be between 1 and 1000."
  }
}

# ===========================
# Network Configuration
# ===========================

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "vpc-network"
}

variable "vpc_egress_setting" {
  description = "VPC egress setting: ALL_TRAFFIC or PRIVATE_RANGES_ONLY"
  type        = string
  default     = "PRIVATE_RANGES_ONLY"

  validation {
    condition     = contains(["ALL_TRAFFIC", "PRIVATE_RANGES_ONLY"], var.vpc_egress_setting)
    error_message = "VPC egress must be 'ALL_TRAFFIC' or 'PRIVATE_RANGES_ONLY'."
  }
}

variable "network_tags" {
  description = "Network tags for Cloud Run service"
  type        = list(string)
  default     = ["nfsserver"]
}

variable "ingress_settings" {
  description = "Ingress settings: all, internal, internal-and-cloud-load-balancing"
  type        = string
  default     = "all"

  validation {
    condition     = contains(["all", "internal", "internal-and-cloud-load-balancing"], var.ingress_settings)
    error_message = "Ingress must be 'all', 'internal', or 'internal-and-cloud-load-balancing'."
  }
}

# ===========================
# Volume Mounts Configuration
# ===========================

variable "nfs_enabled" {
  description = "Enable NFS volume mount"
  type        = bool
  default     = true
}

variable "nfs_mount_path" {
  description = "NFS mount path in container"
  type        = string
  default     = "/mnt"
}

variable "gcs_volumes" {
  description = "GCS FUSE volume mounts configuration"
  type = list(object({
    name        = string
    bucket_name = optional(string, null) # If null, uses auto-created bucket
    mount_path  = string
    readonly    = optional(bool, false)
    mount_options = optional(list(string), [
      "implicit-dirs",
      "stat-cache-ttl=60s",
      "type-cache-ttl=60s"
    ])
  }))
  default = []
}

variable "custom_volumes" {
  description = "Additional custom volume mounts"
  type = list(object({
    name       = string
    mount_path = string
    secret     = optional(string, null)
    config_map = optional(string, null)
  }))
  default = []
}

# ===========================
# Environment Variables
# ===========================

variable "environment_variables" {
  description = "Static environment variables for the application"
  type        = map(string)
  default     = {}
}

variable "secret_environment_variables" {
  description = "Environment variables from Secret Manager (map of env_var_name to secret_name)"
  type        = map(string)
  default     = {}
}

# ===========================
# Health Check Configuration
# ===========================

variable "health_check_config" {
  description = "Health check configuration"
  type = object({
    enabled               = bool
    path                  = optional(string, "/")
    initial_delay_seconds = optional(number, 0)
    timeout_seconds       = optional(number, 1)
    period_seconds        = optional(number, 10)
    failure_threshold     = optional(number, 3)
  })
  default = {
    enabled = true
    path    = "/"
  }
}

variable "startup_probe_config" {
  description = "Startup probe configuration"
  type = object({
    enabled               = bool
    path                  = optional(string, "/")
    initial_delay_seconds = optional(number, 0)
    timeout_seconds       = optional(number, 240)
    period_seconds        = optional(number, 240)
    failure_threshold     = optional(number, 1)
  })
  default = {
    enabled = true
    path    = "/"
  }
}

# ===========================
# Storage Configuration
# ===========================

variable "create_cloud_storage" {
  description = "Create Cloud Storage buckets"
  type        = bool
  default     = true
}

variable "storage_buckets" {
  description = "Cloud Storage buckets to create"
  type = list(object({
    name_suffix           = string
    location              = optional(string, "EU")
    storage_class         = optional(string, "STANDARD")
    force_destroy         = optional(bool, true)
    versioning_enabled    = optional(bool, false)
    lifecycle_rules       = optional(list(any), [])
    public_access_prevention = optional(string, "enforced")
  }))
  default = [
    {
      name_suffix = "data"
      location    = "EU"
    }
  ]
}

# ===========================
# Initialization Jobs Configuration
# ===========================

variable "initialization_jobs" {
  description = "Cloud Run jobs for initialization"
  type = list(object({
    name               = string
    description        = optional(string, "")
    image              = optional(string, null) # Defaults to main container image
    command            = optional(list(string), [])
    args               = optional(list(string), [])
    env_vars           = optional(map(string), {})
    secret_env_vars    = optional(map(string), {})
    cpu_limit          = optional(string, "1000m")
    memory_limit       = optional(string, "512Mi")
    timeout_seconds    = optional(number, 600)
    max_retries        = optional(number, 1)
    task_count         = optional(number, 1)
    execution_mode     = optional(string, "TASK")
    mount_nfs          = optional(bool, false)
    mount_gcs_volumes  = optional(list(string), [])
    depends_on_jobs    = optional(list(string), [])
    execute_on_apply   = optional(bool, false)
    script_path        = optional(string, null)
  }))
  default = []
}

# ===========================
# Monitoring Configuration
# ===========================

variable "configure_monitoring" {
  description = "Configure monitoring and alerting"
  type        = bool
  default     = true
}

variable "trusted_users" {
  description = "Email addresses for monitoring alerts"
  type        = list(string)
  default     = []
}

variable "uptime_check_config" {
  description = "Uptime check configuration"
  type = object({
    enabled         = bool
    path            = optional(string, "/")
    check_interval  = optional(string, "60s")
    timeout         = optional(string, "10s")
  })
  default = {
    enabled = true
    path    = "/"
  }
}

variable "alert_policies" {
  description = "Custom alert policies"
  type = list(object({
    name               = string
    metric_type        = string
    comparison         = string
    threshold_value    = number
    duration_seconds   = number
    aggregation_period = optional(string, "60s")
  }))
  default = []
}

# ===========================
# Service Account Configuration
# ===========================

variable "cloudrun_service_account" {
  description = "Service account for Cloud Run (auto-detected if not provided)"
  type        = string
  default     = null
}

variable "cloudbuild_service_account" {
  description = "Service account for Cloud Build (auto-detected if not provided)"
  type        = string
  default     = null
}

variable "cloudsql_service_account" {
  description = "Service account for Cloud SQL (auto-detected if not provided)"
  type        = string
  default     = null
}

# ===========================
# Feature Flags
# ===========================

variable "configure_environment" {
  description = "Deploy Cloud Run service"
  type        = bool
  default     = true
}

variable "enable_custom_domain" {
  description = "Enable custom domain mapping"
  type        = bool
  default     = false
}

variable "custom_domain" {
  description = "Custom domain for the application"
  type        = string
  default     = null
}

variable "enable_cdn" {
  description = "Enable Cloud CDN (requires load balancer)"
  type        = bool
  default     = false
}

variable "enable_iap" {
  description = "Enable Identity-Aware Proxy"
  type        = bool
  default     = false
}

variable "iap_config" {
  description = "IAP configuration"
  type = object({
    oauth2_client_id     = string
    oauth2_client_secret = string
    allowed_emails       = optional(list(string), [])
    allowed_domains      = optional(list(string), [])
  })
  default = null
}

# ===========================
# Additional Configuration
# ===========================

variable "service_annotations" {
  description = "Additional annotations for Cloud Run service"
  type        = map(string)
  default     = {}
}

variable "service_labels" {
  description = "Additional labels for Cloud Run service"
  type        = map(string)
  default     = {}
}

variable "execution_environment" {
  description = "Execution environment: gen1 or gen2"
  type        = string
  default     = "gen2"

  validation {
    condition     = contains(["gen1", "gen2"], var.execution_environment)
    error_message = "Execution environment must be 'gen1' or 'gen2'."
  }
}

variable "secret_propagation_delay" {
  description = "Delay in seconds after creating secrets before using them"
  type        = number
  default     = 30

  validation {
    condition     = var.secret_propagation_delay >= 0 && var.secret_propagation_delay <= 300
    error_message = "Secret propagation delay must be between 0 and 300 seconds."
  }
}
