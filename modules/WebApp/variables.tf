# Copyright 2024 (c) Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ===========================
# GROUP 0: Module Metadata & Admin Configuration
# ===========================

variable "module_description" {
  description = "The description of the module. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = "This module can be used to deploy Cyclos, Django, Moodle, N8N, Odoo, OpenEMR or Wordpress"
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=101 }}"
  type        = list(string)
  default     = ["GCP_Services"]
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["Cloud Run", "Cloud Build", "Artifact Registry", "Cloud Storage", "Cloud SQL", "Cloud IAM", "Cloud Networking", "Secret Manager"]
}

variable "credit_cost" {
  description = "Specify the module cost. {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 100
}

variable "require_credit_purchases" {
  description = "Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=104 }}"
  type        = bool
  default     = false
}

variable "enable_purge" {
  description = "Set to true to enable the ability to purge this module. {{UIMeta group=0 order=105 }}"
  type        = bool
  default     = true
}

variable "public_access" {
  description = "Set to true to enable the module to be available to all platform users. {{UIMeta group=0 order=106 }}"
  type        = bool
  default     = true
}

variable "deployment_id" {
  description = "Unique ID suffix for resources. Leave blank to generate random ID. {{UIMeta group=0 order=107 }}"
  type        = string
  default     = null
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=0 order=108 updatesafe }}"
  type        = string
  default     = null
}

variable "resource_labels" {
  description = "Labels to apply to all resources. {{UIMeta group=0 order=109 updatesafe }}"
  type        = map(string)
  default     = null
}

variable "deployment_regions" {
  description = "List of regions for multi-region deployment (advanced users only). {{UIMeta group=0 order=110 updatesafe }}"
  type        = list(string)
  default     = []
}

variable "configure_environment" {
  description = "Set to true to deploy Cloud Run service. {{UIMeta group=0 order=111 updatesafe }}"
  type        = bool
  default     = true
}

variable "create_cloud_storage" {
  description = "Set to true to create Cloud Storage buckets. {{UIMeta group=0 order=112 updatesafe }}"
  type        = bool
  default     = true
}

variable "network_name" {
  description = "Name of the VPC network. {{UIMeta group=0 order=114 updatesafe }}"
  type        = string
  default     = "vpc-network"
}

variable "cloudrun_service_account" {
  description = "Service account for Cloud Run (auto-detected if not provided). {{UIMeta group=0 order=115 updatesafe }}"
  type        = string
  default     = null
}

variable "cloudbuild_service_account" {
  description = "Service account for Cloud Build (auto-detected if not provided). {{UIMeta group=0 order=116 updatesafe }}"
  type        = string
  default     = null
}

variable "cloudsql_service_account" {
  description = "Service account for Cloud SQL (auto-detected if not provided). {{UIMeta group=0 order=117 updatesafe }}"
  type        = string
  default     = null
}

variable "execution_environment" {
  description = "Execution environment: gen1 or gen2. {{UIMeta group=0 order=118 updatesafe }}"
  type        = string
  default     = "gen2"

  validation {
    condition     = contains(["gen1", "gen2"], var.execution_environment)
    error_message = "Execution environment must be 'gen1' or 'gen2'."
  }
}

variable "secret_propagation_delay" {
  description = "Delay in seconds after creating secrets before using them (0-300). {{UIMeta group=0 order=119 updatesafe }}"
  type        = number
  default     = 30

  validation {
    condition     = var.secret_propagation_delay >= 0 && var.secret_propagation_delay <= 300
    error_message = "Secret propagation delay must be between 0 and 300 seconds."
  }
}

variable "service_annotations" {
  description = "Additional annotations for Cloud Run service (advanced). {{UIMeta group=0 order=120 updatesafe }}"
  type        = map(string)
  default     = {}
}

variable "service_labels" {
  description = "Additional labels for Cloud Run service (advanced). {{UIMeta group=0 order=121 updatesafe }}"
  type        = map(string)
  default     = {}
}

# ===========================
# GROUP 1: External Project Configuration
# ===========================

variable "agent_service_account" {
  description = "If deploying into an existing GCP project outside of the RAD platform, enter a RAD GCP project agent service account (e.g., rad-agent@gcp-project.iam.gserviceaccount.com) and grant this service account IAM Owner role in the target Google Cloud project. Leave this field blank if deploying into a target project on the RAD platform. {{UIMeta group=1 order=200 updatesafe }}"
  type        = string
  default     = null
}

# ===========================
# GROUP 2: Project & Deployment Configuration
# ===========================

variable "existing_project_id" {
  description = "Select an existing project on the RAD platform or enter the project ID of an external GCP project. You must grant Owner role to the RAD GCP Project agent service account when deploying into an external project. {{UIMeta group=2 order=200 }}"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.existing_project_id))
    error_message = "Project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "tenant_deployment_id" {
  description = "Specify a unique tenant or deployment identifier. This uniquely identifies your application deployment and is used in resource naming (1-20 lowercase alphanumeric characters and hyphens). {{UIMeta group=2 order=201 updatesafe }}"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,20}$", var.tenant_deployment_id))
    error_message = "Tenant ID must be 1-20 characters, lowercase letters, numbers, and hyphens only."
  }
}

variable "deployment_region" {
  description = "Primary deployment region for your application (e.g., us-central1, europe-west1). {{UIMeta group=0 order=202 updatesafe }}"
  type        = string
  default     = "us-central1"
}

# ===========================
# GROUP 3: Application Configuration
# ===========================

variable "application_module" {
  description = "Select a pre-configured application module for automatic configuration. Leave empty or null for manual configuration. When using a module, container image, port, database type, resource limits, and other settings are automatically configured. You can still override any module value by explicitly setting the corresponding variable. {{UIMeta group=3 order=299 OPTIONS=odoo,wordpress,moodle,cyclos,django,openemr,n8n,nextcloud,gitlab,payload updatesafe }}"
  type        = string
  default     = null

  validation {
    condition = var.application_module == null || var.application_module == "" || contains([
      "odoo", "wordpress", "moodle", "cyclos", "django", "openemr", "n8n", "nextcloud", "gitlab", "ghost", "wikijs", "plane"
    ], var.application_module)
    error_message = "Application module must be one of: odoo, wordpress, moodle, cyclos, django, openemr, n8n, nextcloud, gitlab, ghost, wikijs, plane, or leave empty for manual configuration."
  }
}

variable "application_name" {
  description = "Application name used in resource naming. Must start with a letter and contain only lowercase letters, numbers, and hyphens (1-20 characters). {{UIMeta group=0 order=300 updatesafe }}"
  type        = string
  default     = null

  validation {
    condition     = var.application_name == null || can(regex("^[a-z][a-z0-9-]{0,19}$", var.application_name))
    error_message = "Application name must start with a letter, be 1-20 characters, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "application_display_name" {
  description = "Human-readable application name for display purposes. {{UIMeta group=0 order=301 updatesafe }}"
  type        = string
  default     = null
}

variable "application_version" {
  description = "Application version tag (e.g., 1.0.0, latest). {{UIMeta group=0 order=302 updatesafe }}"
  type        = string
  default     = "latest"
}

variable "application_description" {
  description = "Brief description of your application. {{UIMeta group=0 order=303 updatesafe }}"
  type        = string
  default     = ""
}

variable "application_database_name" {
  description = "Application database name. Must start with a letter and contain only lowercase letters, numbers, and underscores (1-63 characters). The actual database name includes tenant ID and deployment ID to ensure uniqueness. {{UIMeta group=0 order=304 updatesafe }}"
  type        = string
  default     = null

  validation {
    condition     = var.application_database_name == null || can(regex("^[a-z][a-z0-9_]{0,62}$", var.application_database_name))
    error_message = "Database name must start with a letter, be 1-63 characters, and contain only lowercase letters, numbers, and underscores."
  }
}

variable "application_database_user" {
  description = "Application database user. Must start with a letter and contain only lowercase letters, numbers, and underscores (1-32 characters). The actual database user includes tenant ID and deployment ID to ensure uniqueness. {{UIMeta group=0 order=305 updatesafe }}"
  type        = string
  default     = null

  validation {
    condition     = var.application_database_user == null || can(regex("^[a-z][a-z0-9_]{0,31}$", var.application_database_user))
    error_message = "Database user must start with a letter, be 1-32 characters, and contain only lowercase letters, numbers, and underscores."
  }
}

# ===========================
# GROUP 4: Container Configuration
# ===========================

variable "container_image_source" {
  description = "Container image source: 'prebuilt' (use existing image from registry) or 'custom' (build from Dockerfile). {{UIMeta group=0 order=400 updatesafe }}"
  type        = string
  default     = null

  validation {
    condition     = var.container_image_source == null || contains(["prebuilt", "custom"], coalesce(var.container_image_source, "prebuilt"))
    error_message = "Container image source must be 'prebuilt' or 'custom'."
  }
}

variable "container_image" {
  description = "Pre-built container image (e.g., 'nginx:latest', 'gcr.io/project/app:v1'). Required when container_image_source='prebuilt' unless using an application_module. {{UIMeta group=0 order=401 updatesafe }}"
  type        = string
  default     = ""
}

variable "container_port" {
  description = "Container port to expose (1-65535). {{UIMeta group=0 order=402 updatesafe }}"
  type        = number
  default     = null

  validation {
    condition     = var.container_port == null || (coalesce(var.container_port, 8080) > 0 && coalesce(var.container_port, 8080) <= 65535)
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "container_protocol" {
  description = "Container protocol: 'http1' or 'h2c' (HTTP/2 Cleartext). {{UIMeta group=0 order=403 updatesafe }}"
  type        = string
  default     = "http1"

  validation {
    condition     = contains(["http1", "h2c"], var.container_protocol)
    error_message = "Container protocol must be 'http1' or 'h2c'."
  }
}

variable "container_build_config" {
  description = "Custom container build configuration. Required when container_image_source='custom'. Provide Dockerfile path or content, build context, and optional build arguments. {{UIMeta group=0 order=404 updatesafe }}"
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

variable "github_repository_url" {
  description = "GitHub repository URL for automated CI/CD (e.g., 'https://github.com/username/repo'). Required when using Cloud Build triggers for automated deployments. {{UIMeta group=0 order=405 updatesafe }}"
  type        = string
  default     = null
}

variable "github_token_secret_name" {
  description = "Name of the secret in Secret Manager containing the GitHub personal access token. The secret must be created manually before running Terraform. Required when enable_cicd_trigger is true. To generate: https://github.com/settings/tokens -> Generate new token (classic). Scopes: repo, admin:repo_hook, workflow, read:org. {{UIMeta group=0 order=406 updatesafe }}"
  type        = string
  default     = "github-token"
}

variable "github_app_installation_id" {
  description = "GitHub App installation ID for Cloud Build v2 connection. Required when enable_cicd_trigger is true. To find ID: https://github.com/settings/installations -> Configure. ID is at the end of the URL. {{UIMeta group=0 order=407 updatesafe }}"
  type        = string
  default     = null
}

variable "enable_cicd_trigger" {
  description = "Enable automated Cloud Build trigger for CI/CD. When enabled, pushes to the main branch will automatically build and deploy your application. {{UIMeta group=0 order=408 updatesafe }}"
  type        = bool
  default     = false
}

variable "cicd_trigger_config" {
  description = "Cloud Build trigger configuration for automated CI/CD pipeline. Configure branch patterns, included/ignored files, and build settings. {{UIMeta group=0 order=409 updatesafe }}"
  type = object({
    branch_pattern     = optional(string, "^main$")
    included_files     = optional(list(string), [])
    ignored_files      = optional(list(string), [])
    trigger_name       = optional(string, null)
    description        = optional(string, "Automated build and deployment trigger")
    substitutions      = optional(map(string), {})
  })
  default = {
    branch_pattern = "^main$"
    description    = "Automated build and deployment trigger"
  }
}

# ===========================
# GROUP 5: Database Configuration
# ===========================

variable "database_type" {
  description = "Database type: MYSQL, POSTGRES, SQLSERVER (or specific versions like MYSQL_8_0, POSTGRES_15). {{UIMeta group=0 order=500 updatesafe }}"
  type        = string
  default     = null

  validation {
    condition     = var.database_type == null || contains(["MYSQL", "POSTGRES", "POSTGRESQL", "SQLSERVER", "MYSQL_5_6", "MYSQL_5_7", "MYSQL_8_0", "POSTGRES_9_6", "POSTGRES_10", "POSTGRES_11", "POSTGRES_12", "POSTGRES_13", "POSTGRES_14", "POSTGRES_15", "SQLSERVER_2017_STANDARD", "SQLSERVER_2017_ENTERPRISE", "SQLSERVER_2019_STANDARD", "SQLSERVER_2019_ENTERPRISE"], coalesce(var.database_type, "POSTGRES"))
    error_message = "Database type must be a valid Cloud SQL database version."
  }
}

variable "database_password_length" {
  description = "Length of auto-generated database password (8-64 characters). {{UIMeta group=0 order=501 updatesafe }}"
  type        = number
  default     = 16

  validation {
    condition     = var.database_password_length >= 8 && var.database_password_length <= 64
    error_message = "Password length must be between 8 and 64 characters."
  }
}

# ===========================
# GROUP 6: Resources & Scaling Configuration
# ===========================

variable "container_resources" {
  description = "Container resource limits. Specify CPU (e.g., '1000m' for 1 CPU) and memory (e.g., '512Mi', '2Gi'). {{UIMeta group=0 order=600 updatesafe }}"
  type = object({
    cpu_limit    = string
    memory_limit = string
    cpu_request  = optional(string, null)
    mem_request  = optional(string, null)
  })
  default = null
}

variable "timeout_seconds" {
  description = "Request timeout in seconds (0-3600). Maximum time a request can take. {{UIMeta group=0 order=602 updatesafe }}"
  type        = number
  default     = 300

  validation {
    condition     = var.timeout_seconds >= 0 && var.timeout_seconds <= 3600
    error_message = "Timeout must be between 0 and 3600 seconds."
  }
}

variable "min_instance_count" {
  description = "Minimum number of container instances (0-1000). Set to 0 to scale to zero when idle (cost-effective). {{UIMeta group=0 order=603 updatesafe }}"
  type        = number
  default     = null

  validation {
    condition     = var.min_instance_count == null || (coalesce(var.min_instance_count, 0) >= 0 && coalesce(var.min_instance_count, 0) <= 1000)
    error_message = "Minimum instance count must be between 0 and 1000."
  }
}

variable "max_instance_count" {
  description = "Maximum number of container instances (1-1000). Controls maximum scale under load. {{UIMeta group=0 order=604 updatesafe }}"
  type        = number
  default     = null

  validation {
    condition     = var.max_instance_count == null || (coalesce(var.max_instance_count, 1) >= 1 && coalesce(var.max_instance_count, 1) <= 1000)
    error_message = "Maximum instance count must be between 1 and 1000."
  }
}

# ===========================
# GROUP 7: Storage & Volume Configuration
# ===========================

variable "storage_buckets" {
  description = "Cloud Storage buckets to create. Specify name suffix, location (e.g., 'US', 'EU'), storage class, versioning, and lifecycle rules. {{UIMeta group=0 order=700 updatesafe }}"
  type = list(object({
    name_suffix              = string
    location                 = optional(string, "EU")
    storage_class            = optional(string, "STANDARD")
    force_destroy            = optional(bool, true)
    versioning_enabled       = optional(bool, false)
    lifecycle_rules          = optional(list(any), [])
    public_access_prevention = optional(string, "enforced")
  }))
  default = [
    {
      name_suffix = "data"
      location    = "EU"
    }
  ]
}

variable "nfs_enabled" {
  description = "Enable NFS volume mount for persistent file storage. {{UIMeta group=0 order=701 updatesafe }}"
  type        = bool
  default     = null
}

variable "nfs_mount_path" {
  description = "NFS mount path in container (e.g., '/mnt', '/data'). {{UIMeta group=0 order=702 updatesafe }}"
  type        = string
  default     = null
}

variable "gcs_volumes" {
  description = "GCS FUSE volume mounts. Specify volume name, bucket name (null for auto-created), mount path, readonly mode, and mount options. {{UIMeta group=0 order=703 updatesafe }}"
  type = list(object({
    name        = string
    bucket_name = optional(string, null)
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

variable "enable_cloudsql_volume" {
  description = "Enable Cloud SQL instance volume for Unix socket connections. When enabled, the Cloud SQL instance will be mounted as a volume, allowing connections via Unix socket instead of TCP/IP. {{UIMeta group=0 order=705 updatesafe }}"
  type        = bool
  default     = null
}

variable "cloudsql_volume_mount_path" {
  description = "Mount path for Cloud SQL Unix socket (e.g., '/cloudsql'). Only used when enable_cloudsql_volume is true. {{UIMeta group=0 order=706 updatesafe }}"
  type        = string
  default     = null
}

# ===========================
# GROUP 8: Environment Variables
# ===========================

variable "environment_variables" {
  description = "Static environment variables for the application as key-value pairs (e.g., {APP_ENV='production', LOG_LEVEL='info'}). {{UIMeta group=0 order=800 updatesafe }}"
  type        = map(string)
  default     = {}
}

variable "secret_environment_variables" {
  description = "Environment variables from Secret Manager. Map environment variable name to Secret Manager secret name (e.g., {API_KEY='my-api-key-secret'}). {{UIMeta group=0 order=801 updatesafe }}"
  type        = map(string)
  default     = {}
}

# ===========================
# GROUP 9: Health Check Configuration
# ===========================

variable "health_check_config" {
  description = "Liveness probe configuration. Checks if the application is running and restarts if unhealthy. {{UIMeta group=0 order=900 updatesafe }}"
  type = object({
    enabled               = bool
    type                  = optional(string, "HTTP")
    path                  = optional(string, "/")
    initial_delay_seconds = optional(number, 0)
    timeout_seconds       = optional(number, 1)
    period_seconds        = optional(number, 10)
    failure_threshold     = optional(number, 3)
  })
  default = null
}

variable "startup_probe_config" {
  description = "Startup probe configuration. Checks if the application has started successfully before accepting traffic. {{UIMeta group=0 order=901 updatesafe }}"
  type = object({
    enabled               = bool
    type                  = optional(string, "TCP")
    path                  = optional(string, "/")
    initial_delay_seconds = optional(number, 0)
    timeout_seconds       = optional(number, 240)
    period_seconds        = optional(number, 240)
    failure_threshold     = optional(number, 1)
  })
  default = null
}

# ===========================
# GROUP 10: Monitoring & Alerting Configuration
# ===========================

variable "trusted_users" {
  description = "Email addresses for monitoring alerts and notifications (e.g., ['admin@example.com', 'ops@example.com']). {{UIMeta group=0 order=1000 updatesafe }}"
  type        = list(string)
  default     = []
}

variable "uptime_check_config" {
  description = "Uptime check configuration. Monitors service availability and sends alerts on failures. {{UIMeta group=0 order=1001 updatesafe }}"
  type = object({
    enabled        = bool
    path           = optional(string, "/")
    check_interval = optional(string, "60s")
    timeout        = optional(string, "10s")
  })
  default = {
    enabled = true
    path    = "/"
  }
}

variable "alert_policies" {
  description = "Custom alert policies. Define metric-based alerts for your application (e.g., error rates, latency). {{UIMeta group=0 order=1002 updatesafe }}"
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
# GROUP 11: Initialization Jobs Configuration
# ===========================

variable "initialization_jobs" {
  description = "Cloud Run jobs for initialization tasks (e.g., database migrations, data seeding). Jobs can mount NFS/GCS volumes and access secrets. {{UIMeta group=0 order=1100 updatesafe }}"
  type = list(object({
    name              = string
    description       = optional(string, "")
    image             = optional(string, null)
    command           = optional(list(string), [])
    args              = optional(list(string), [])
    env_vars          = optional(map(string), {})
    secret_env_vars   = optional(map(string), {})
    cpu_limit         = optional(string, "1000m")
    memory_limit      = optional(string, "512Mi")
    timeout_seconds   = optional(number, 600)
    max_retries       = optional(number, 1)
    task_count        = optional(number, 1)
    execution_mode    = optional(string, "TASK")
    mount_nfs         = optional(bool, false)
    mount_gcs_volumes = optional(list(string), [])
    depends_on_jobs   = optional(list(string), [])
    execute_on_apply  = optional(bool, false)
    script_path       = optional(string, null)
  }))
  default = []
}

# ===========================
# GROUP 13: Database Extensions & Backup Configuration
# ===========================

variable "enable_postgres_extensions" {
  description = "Enable automatic installation of PostgreSQL extensions. Only applicable when using PostgreSQL databases. {{UIMeta group=0 order=1300 updatesafe }}"
  type        = bool
  default     = false
}

variable "postgres_extensions" {
  description = "List of PostgreSQL extensions to install (e.g., ['postgis', 'uuid-ossp', 'pg_trgm']). Common extensions: postgis, cube, earthdistance, unaccent, pg_stat_statements, uuid-ossp, pg_trgm. {{UIMeta group=0 order=1301 updatesafe }}"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for ext in var.postgres_extensions : can(regex("^[a-z_][a-z0-9_-]*$", ext))])
    error_message = "Extension names must start with a letter or underscore and contain only lowercase letters, numbers, underscores, and hyphens."
  }
}

# Unified Backup Import Configuration (Recommended)
variable "enable_backup_import" {
  description = "Enable automatic import of database backup during deployment. Use backup_source to specify Google Drive or Google Cloud Storage. {{UIMeta group=0 order=1302 updatesafe }}"
  type        = bool
  default     = false
}

variable "backup_source" {
  description = "Backup source: 'gdrive' (Google Drive) or 'gcs' (Google Cloud Storage). GCS is recommended for production due to better security and performance. {{UIMeta group=0 order=1303 updatesafe }}"
  type        = string
  default     = "gcs"

  validation {
    condition     = contains(["gdrive", "gcs"], var.backup_source)
    error_message = "Backup source must be 'gdrive' or 'gcs'."
  }
}

variable "backup_uri" {
  description = "Backup URI. For GCS: full URI like 'gs://bucket/path/backup.sql'. For Google Drive: file ID from URL 'https://drive.google.com/file/d/FILE_ID/view'. {{UIMeta group=0 order=1304 updatesafe }}"
  type        = string
  default     = ""
}

variable "backup_format" {
  description = "Backup file format. For GCS: 'sql', 'tar', 'gz', 'tgz', 'tar.gz', 'zip'. For Google Drive: 'sql', 'tar', 'zip'. {{UIMeta group=0 order=1305 updatesafe }}"
  type        = string
  default     = "sql"

  validation {
    condition     = contains(["sql", "tar", "gz", "tgz", "tar.gz", "zip"], var.backup_format)
    error_message = "Backup format must be 'sql', 'tar', 'gz', 'tgz', 'tar.gz', or 'zip'."
  }
}

# Legacy Variables (Deprecated - Use unified variables above)
variable "enable_gdrive_backup_import" {
  description = "DEPRECATED: Use enable_backup_import with backup_source='gdrive' instead. Enable automatic import of database backup from Google Drive. {{UIMeta group=0 order=1320 updatesafe }}"
  type        = bool
  default     = false
}

variable "gdrive_backup_file_id" {
  description = "DEPRECATED: Use backup_uri instead. Google Drive file ID of the backup to import. {{UIMeta group=0 order=1321 updatesafe }}"
  type        = string
  default     = ""
}

variable "gdrive_backup_format" {
  description = "DEPRECATED: Use backup_format instead. Backup file format for Google Drive. {{UIMeta group=0 order=1322 updatesafe }}"
  type        = string
  default     = "sql"

  validation {
    condition     = contains(["sql", "tar", "zip"], var.gdrive_backup_format)
    error_message = "Backup format must be 'sql', 'tar', or 'zip'."
  }
}

variable "enable_gcs_backup_import" {
  description = "DEPRECATED: Use enable_backup_import with backup_source='gcs' instead. Enable automatic import of database backup from Google Cloud Storage. {{UIMeta group=0 order=1323 updatesafe }}"
  type        = bool
  default     = false
}

variable "gcs_backup_uri" {
  description = "DEPRECATED: Use backup_uri instead. Google Cloud Storage URI of the backup to import. {{UIMeta group=0 order=1324 updatesafe }}"
  type        = string
  default     = ""
}

variable "gcs_backup_format" {
  description = "DEPRECATED: Use backup_format instead. Backup file format for GCS import. {{UIMeta group=0 order=1325 updatesafe }}"
  type        = string
  default     = "sql"

  validation {
    condition     = contains(["sql", "tar", "gz", "tgz", "tar.gz", "zip"], var.gcs_backup_format)
    error_message = "Backup format must be 'sql', 'tar', 'gz', 'tgz', 'tar.gz', or 'zip'."
  }
}

variable "enable_mysql_plugins" {
  description = "Enable automatic installation of MySQL plugins and components. Only applicable when using MySQL databases. {{UIMeta group=0 order=1308 updatesafe }}"
  type        = bool
  default     = false
}

variable "mysql_plugins" {
  description = "List of MySQL plugins to install (e.g., ['audit_log', 'validate_password']). Common plugins: validate_password, audit_log, clone, group_replication, authentication_ldap_simple. {{UIMeta group=0 order=1309 updatesafe }}"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for plugin in var.mysql_plugins : can(regex("^[a-z_][a-z0-9_]*$", plugin))])
    error_message = "Plugin names must start with a letter or underscore and contain only lowercase letters, numbers, and underscores."
  }
}

variable "enable_custom_sql_scripts" {
  description = "Enable execution of custom SQL scripts from GCS during initialization. Useful for seeding data, creating additional schemas, or running custom DDL. {{UIMeta group=0 order=1310 updatesafe }}"
  type        = bool
  default     = false
}

variable "custom_sql_scripts_bucket" {
  description = "GCS bucket name containing custom SQL scripts (without gs:// prefix, e.g., 'my-bucket'). Only used when enable_custom_sql_scripts is true. {{UIMeta group=0 order=1311 updatesafe }}"
  type        = string
  default     = ""
}

variable "custom_sql_scripts_path" {
  description = "Path prefix in GCS bucket for SQL scripts (e.g., 'scripts/init/'). Scripts will be executed in alphabetical order. Name scripts with numeric prefixes for ordering (e.g., 001_schema.sql, 002_data.sql). {{UIMeta group=0 order=1312 updatesafe }}"
  type        = string
  default     = ""
}

variable "custom_sql_scripts_use_root" {
  description = "Execute custom SQL scripts as database root user instead of application user. Enable this for scripts that require elevated privileges (e.g., creating users, installing extensions). {{UIMeta group=0 order=1313 updatesafe }}"
  type        = bool
  default     = false
}

# ===========================
# GROUP 12: Network & Security Configuration
# ===========================

variable "vpc_egress_setting" {
  description = "VPC egress setting: 'ALL_TRAFFIC' (route all through VPC) or 'PRIVATE_RANGES_ONLY' (only private IPs through VPC, public direct). {{UIMeta group=0 order=1200 updatesafe }}"
  type        = string
  default     = "PRIVATE_RANGES_ONLY"

  validation {
    condition     = contains(["ALL_TRAFFIC", "PRIVATE_RANGES_ONLY"], var.vpc_egress_setting)
    error_message = "VPC egress must be 'ALL_TRAFFIC' or 'PRIVATE_RANGES_ONLY'."
  }
}

variable "network_tags" {
  description = "Network tags for Cloud Run service (e.g., ['nfsserver', 'web']). {{UIMeta group=0 order=1201 updatesafe }}"
  type        = list(string)
  default     = ["nfsserver"]
}

variable "ingress_settings" {
  description = "Ingress settings: 'all' (public internet), 'internal' (VPC only), or 'internal-and-cloud-load-balancing'. {{UIMeta group=0 order=1202 updatesafe }}"
  type        = string
  default     = "all"

  validation {
    condition     = contains(["all", "internal", "internal-and-cloud-load-balancing"], var.ingress_settings)
    error_message = "Ingress must be 'all', 'internal', or 'internal-and-cloud-load-balancing'."
  }
}
