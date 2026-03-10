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
# SECTION 0: Metadata
# ===========================

variable "module_description" {
  description = "The description of the module. {{UIMeta group=0 order=101 }}"
  type        = string
  default     = "OpenEMR: Deploy open-source Electronic Health Records (EHR) and medical practice management solution on Google Cloud Run. HIPAA-compliant-ready environment for secure patient data, scheduling, and billing with full data sovereignty. Includes OpenEMR PHP application (Apache/PHP 8.3 FPM on Alpine 3.20), MySQL 8.0 database with Unix socket connection, external NFS server for patient documents and sites directory, Redis for session management, and automated SSL certificate management. Features 3-tier serverless architecture, Direct VPC Egress, Secret Manager encryption, automated backup restoration from GCS/Google Drive, nfs-init job for storage preparation, startup/liveness probes, Cloud Logging integration, and configurable ingress. Built on Google Cloud's secure foundation with encrypted databases, private networking, high availability for clinician access, and integrated disaster recovery. Ideal for healthcare providers needing secure EHR hosting, HIPAA compliance, patient data sovereignty, and disaster recovery protection."
}

variable "module_documentation" {
  description = "The URL to the module documentation. {{UIMeta group=0 order=102 }}"
  type        = string
  default     = "https://docs.techequity.cloud/docs/applications/openemr"
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=103 }}"
  type        = list(string)
  default     = ["GCP_Services"]
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=104 }}"
  type        = list(string)
  default     = ["Cloud Run Gen 2", "Cloud Run Jobs", "Cloud Build", "Artifact Registry", "Cloud Storage", "Google Drive API", "Cloud SQL", "Cloud SQL Auth Proxy", "MySQL 8.0", "Compute Engine", "NFS Server", "Redis", "VPC Network", "Direct VPC Egress", "Private IP", "Serverless VPC Access", "Secret Manager", "Cloud IAM", "Cloud Logging", "Cloud Monitoring", "Health Checks", "SSL Certificate Management", "Automated Backups"]
}

variable "credit_cost" {
  description = "Specify the module cost. {{UIMeta group=0 order=105 }}"
  type        = number
  default     = 100
}

variable "require_credit_purchases" {
  description = "Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=106 }}"
  type        = bool
  default     = false
}

variable "enable_purge" {
  description = "Set to true to enable the ability to purge this module. {{UIMeta group=0 order=107 }}"
  type        = bool
  default     = true
}

variable "public_access" {
  description = "Set to true to enable the module to be available to all platform users. {{UIMeta group=0 order=108 }}"
  type        = bool
  default     = true
}

# ===========================
# SECTION 2: Project
# ===========================

variable "existing_project_id" {
  description = "Select an existing project on the RAD platform or enter the project ID of an external GCP project. You must grant Owner role to the RAD GCP Project agent service account when deploying into an external project. {{UIMeta group=1 order=2001 }}"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.existing_project_id))
    error_message = "Project ID must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "trusted_users" {
  description = "Email addresses of users to be granted access the Google Cloud project, monitoring alerts and notifications (e.g., ['admin@example.com', 'ops@example.com']). {{UIMeta group=0 order=2002 updatesafe }}"
  type        = list(string)
  default     = []
}

# ===========================
# SECTION 3: Service Accounts
# ===========================

variable "resource_creator_identity" {
  description = "The Service Account used by terraform to create resources in the destination project. Assign time limited conditional Basic Owner IAM role in the destination project. {{UIMeta group=0 order=301 }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "agent_service_account" {
  description = "If deploying into an existing GCP project outside of the RAD platform, enter a RAD GCP project agent service account (e.g., rad-agent@gcp-project.iam.gserviceaccount.com) and grant this service account IAM Owner role in the target Google Cloud project. Leave this field blank if deploying into a target project on the RAD platform. {{UIMeta group=0 order=302 updatesafe }}"
  type        = string
  default     = ""
}

variable "cloudrun_service_account" {
  description = "Service account for Cloud Run (auto-detected if not provided). {{UIMeta group=0 order=303 updatesafe }}"
  type        = string
  default     = ""
}

variable "cloudbuild_service_account" {
  description = "Service account for Cloud Build (auto-detected if not provided). {{UIMeta group=0 order=304 updatesafe }}"
  type        = string
  default     = ""
}

variable "cloudsql_service_account" {
  description = "Service account for Cloud SQL (auto-detected if not provided). {{UIMeta group=0 order=305 updatesafe }}"
  type        = string
  default     = ""
}

# ===========================
# SECTION 4: Deployment
# ===========================

variable "deployment_id" {
  description = "Unique ID suffix for resources. Leave blank to generate random ID. {{UIMeta group=0 order=401 }}"
  type        = string
  default     = null
}

variable "configure_environment" {
  description = "Set to true to deploy Cloud Run service. {{UIMeta group=0 order=402 updatesafe }}"
  type        = bool
  default     = true
}

variable "tenant_deployment_id" {
  description = "Specify a unique tenant or deployment identifier. This uniquely identifies your application deployment and is used in resource naming (1-20 lowercase alphanumeric characters and hyphens). {{UIMeta group=1 order=4001 updatesafe }}"
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z0-9-]{1,20}$", var.tenant_deployment_id))
    error_message = "Tenant ID must be 1-20 characters, lowercase letters, numbers, and hyphens only."
  }
}

variable "application_version" {
  description = "Application version tag (e.g., 7.0.4, latest). {{UIMeta group=0 order=4002 updatesafe }}"
  type        = string
  default     = "7.0.4"
}

variable "resource_labels" {
  description = "Labels to apply to all resources. {{UIMeta group=0 order=4003 updatesafe }}"
  type        = map(string)
  default     = {}
}

# ===========================
# SECTION 5: Network
# ===========================

variable "network_name" {
  description = "Name of the VPC network. {{UIMeta group=0 order=501 updatesafe }}"
  type        = string
  default     = "vpc-network"
}

variable "deployment_region" {
  description = "Primary deployment region for your application (e.g., us-central1, europe-west1). {{UIMeta group=0 order=502 updatesafe }}"
  type        = string
  default     = "us-central1"
}

variable "deployment_regions" {
  description = "List of regions for multi-region deployment (advanced users only). {{UIMeta group=0 order=503 updatesafe }}"
  type        = list(string)
  default     = ["us-central1"]
}

# ===========================
# SECTION 6: Storage
# ===========================

variable "create_cloud_storage" {
  description = "Set to true to create Cloud Storage buckets. {{UIMeta group=0 order=601 updatesafe }}"
  type        = bool
  default     = true
}

variable "storage_buckets" {
  description = "Cloud Storage buckets to create. Specify name suffix, location (e.g., 'US', 'EU'), storage class, versioning, and lifecycle rules. {{UIMeta group=0 order=602 updatesafe }}"
  type = list(object({
    name_suffix              = string
    location                 = optional(string, "US")
    storage_class            = optional(string, "STANDARD")
    force_destroy            = optional(bool, true)
    versioning_enabled       = optional(bool, false)
    lifecycle_rules          = optional(list(any), [])
    public_access_prevention = optional(string, "enforced")
    uniform_bucket_level_access = optional(bool, false)
  }))
  default = [
    {
      name_suffix = "data"
      location    = "US"
    }
  ]
}

# ===========================
# SECTION 7: NFS & Redis
# ===========================

variable "enable_nfs" {
  description = "Enable NFS volume mount for persistent file storage. {{UIMeta group=0 order=701 updatesafe }}"
  type        = bool
  default     = true
}

variable "nfs_mount_path" {
  description = "NFS mount path in container (e.g., '/mnt', '/data'). {{UIMeta group=0 order=702 updatesafe }}"
  type        = string
  default     = "/var/www/localhost/htdocs/openemr/sites"
}

variable "enable_redis" {
  description = "Set to true to enable Redis configuration. If enabled and no host is provided, it defaults to the NFS server. {{UIMeta group=0 order=703 updatesafe }}"
  type        = bool
  default     = true
}

variable "redis_host" {
  description = "Hostname or IP of the Redis server. If left blank and enable_redis is true, defaults to the NFS server IP. {{UIMeta group=0 order=704 updatesafe }}"
  type        = string
  default     = ""
}

variable "redis_port" {
  description = "Port of the Redis server. {{UIMeta group=0 order=705 updatesafe }}"
  type        = string
  default     = "6379"
}

# ===========================
# SECTION 8: CloudRun
# ===========================

variable "service_annotations" {
  description = "Additional annotations for Cloud Run service (advanced). {{UIMeta group=0 order=801 updatesafe }}"
  type        = map(string)
  default     = {}
}

variable "service_labels" {
  description = "Additional labels for Cloud Run service (advanced). {{UIMeta group=0 order=802 updatesafe }}"
  type        = map(string)
  default     = {}
}

variable "execution_environment" {
  description = "Execution environment: gen1 or gen2. {{UIMeta group=0 order=803 updatesafe }}"
  type        = string
  default     = "gen2"

  validation {
    condition     = contains(["gen1", "gen2"], var.execution_environment)
    error_message = "Execution environment must be 'gen1' or 'gen2'."
  }
}

variable "timeout_seconds" {
  description = "Request timeout in seconds (0-3600). Maximum time a request can take. {{UIMeta group=0 order=804 updatesafe }}"
  type        = number
  default     = 300

  validation {
    condition     = var.timeout_seconds >= 0 && var.timeout_seconds <= 3600
    error_message = "Timeout must be between 0 and 3600 seconds."
  }
}

variable "ingress_settings" {
  description = "Ingress settings: 'all' (public internet), 'internal' (VPC only), or 'internal-and-cloud-load-balancing'. {{UIMeta group=0 order=8001 updatesafe }}"
  type        = string
  default     = "all"

  validation {
    condition     = contains(["all", "internal", "internal-and-cloud-load-balancing"], var.ingress_settings)
    error_message = "Ingress must be 'all', 'internal', or 'internal-and-cloud-load-balancing'."
  }
}

variable "vpc_egress_setting" {
  description = "VPC egress setting: 'ALL_TRAFFIC' (route all through VPC) or 'PRIVATE_RANGES_ONLY' (only private IPs through VPC, public direct). {{UIMeta group=0 order=806 updatesafe }}"
  type        = string
  default     = "PRIVATE_RANGES_ONLY"

  validation {
    condition     = contains(["ALL_TRAFFIC", "PRIVATE_RANGES_ONLY"], var.vpc_egress_setting)
    error_message = "VPC egress must be 'ALL_TRAFFIC' or 'PRIVATE_RANGES_ONLY'."
  }
}

variable "network_tags" {
  description = "Network tags for Cloud Run service (e.g., ['nfsserver', 'web']). {{UIMeta group=0 order=807 updatesafe }}"
  type        = list(string)
  default     = ["nfsserver"]
}

variable "secret_propagation_delay" {
  description = "Delay in seconds after creating secrets before using them (0-300). {{UIMeta group=0 order=808 updatesafe }}"
  type        = number
  default     = 30

  validation {
    condition     = var.secret_propagation_delay >= 0 && var.secret_propagation_delay <= 300
    error_message = "Secret propagation delay must be between 0 and 300 seconds."
  }
}

variable "environment_variables" {
  description = "Static environment variables for the application as key-value pairs (e.g., {APP_ENV='production', LOG_LEVEL='info'}). {{UIMeta group=0 order=8002 updatesafe }}"
  type        = map(string)
  default     = {}
}

variable "secret_environment_variables" {
  description = "Environment variables from Secret Manager. Map environment variable name to Secret Manager secret name (e.g., {API_KEY='my-api-key-secret'}). {{UIMeta group=0 order=8003 updatesafe }}"
  type        = map(string)
  default     = {}
}

variable "database_password_length" {
  description = "Length of auto-generated database password (8-64 characters). {{UIMeta group=0 order=809 updatesafe }}"
  type        = number
  default     = 16

  validation {
    condition     = var.database_password_length >= 8 && var.database_password_length <= 64
    error_message = "Password length must be between 8 and 64 characters."
  }
}

variable "gcs_volumes" {
  description = "GCS FUSE volume mounts. Specify volume name, bucket name (null for auto-created), mount path, readonly mode, and mount options. {{UIMeta group=0 order=811 updatesafe }}"
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

variable "initialization_jobs" {
  description = "Cloud Run jobs for initialization tasks (e.g., database migrations, data seeding). Jobs can mount NFS/GCS volumes and access secrets. {{UIMeta group=0 order=812 updatesafe }}"
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
# SECTION 9: Database Backup
# ===========================

variable "backup_schedule" {
  description = "Cron schedule for automated database and NFS backups (e.g., '0 2 * * *' for daily at 2am). Leave empty to disable scheduled backups. {{UIMeta group=0 order=9001 updatesafe }}"
  type        = string
  default     = "0 2 * * *"
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups. {{UIMeta group=0 order=9002 updatesafe }}"
  type        = number
  default     = 7
}

# ===========================
# SECTION 10: Backup Import
# ===========================

variable "enable_backup_import" {
  description = "Enable automatic import of database backup during deployment. Use backup_source to specify Google Drive or Google Cloud Storage. {{UIMeta group=0 order=10001 updatesafe }}"
  type        = bool
  default     = false
}

variable "backup_source" {
  description = "Backup source: 'gdrive' (Google Drive) or 'gcs' (Google Cloud Storage). GCS is recommended for production due to better security and performance. {{UIMeta group=0 order=10002 updatesafe }}"
  type        = string
  default     = "gcs"

  validation {
    condition     = contains(["gdrive", "gcs"], var.backup_source)
    error_message = "Backup source must be 'gdrive' or 'gcs'."
  }
}

variable "backup_uri" {
  description = "Backup URI. For GCS: full URI like 'gs://bucket/path/backup.sql'. For Google Drive: file ID from URL 'https://drive.google.com/file/d/FILE_ID/view'. {{UIMeta group=0 order=10003 updatesafe }}"
  type        = string
  default     = ""
}

variable "backup_format" {
  description = "Backup file format. For GCS: 'sql', 'tar', 'gz', 'tgz', 'tar.gz', 'zip'. For Google Drive: 'sql', 'tar', 'zip'. {{UIMeta group=0 order=10004 updatesafe }}"
  type        = string
  default     = "sql"

  validation {
    condition     = contains(["sql", "tar", "gz", "tgz", "tar.gz", "zip"], var.backup_format)
    error_message = "Backup format must be 'sql', 'tar', 'gz', 'tgz', 'tar.gz', or 'zip'."
  }
}

# ===========================
# SECTION 11: Cloud Build & Github
# ===========================

variable "enable_cicd_trigger" {
  description = "Enable automated Cloud Build trigger for CI/CD. When enabled, pushes to the main branch will automatically build and deploy your application. {{UIMeta group=0 order=11001 updatesafe }}"
  type        = bool
  default     = false
}

variable "cicd_trigger_config" {
  description = "Cloud Build trigger configuration for automated CI/CD pipeline. Configure branch patterns, included/ignored files, and build settings. {{UIMeta group=0 order=11002 updatesafe }}"
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

variable "github_repository_url" {
  description = "GitHub repository URL for automated CI/CD (e.g., 'https://github.com/username/repo'). Required when using Cloud Build triggers for automated deployments. {{UIMeta group=0 order=11003 updatesafe }}"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub Personal Access Token (PAT). Required when enable_cicd_trigger is true. To generate: https://github.com/settings/tokens -> Generate new token (classic). Scopes: repo, admin:repo_hook, workflow, read:user, user:email, read:org. {{UIMeta group=0 order=11004 updatesafe }}"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_app_installation_id" {
  description = "GitHub App installation ID (RECOMMENDED). Use with github_token_secret_name to avoid manual approval and 'Configuration incomplete' state. To find: https://github.com/settings/installations -> Configure Google Cloud Build -> Copy ID from URL. {{UIMeta group=0 order=11005 updatesafe }}"
  type        = string
  default     = ""
}

# ===========================
# SECTION 12: SQL Configuration
# ===========================

variable "enable_custom_sql_scripts" {
  description = "Enable execution of custom SQL scripts from GCS during initialization. Useful for seeding data, creating additional schemas, or running custom DDL. {{UIMeta group=0 order=12001 updatesafe }}"
  type        = bool
  default     = false
}

variable "custom_sql_scripts_use_root" {
  description = "Execute custom SQL scripts as database root user instead of application user. Enable this for scripts that require elevated privileges (e.g., creating users, installing extensions). {{UIMeta group=0 order=12002 updatesafe }}"
  type        = bool
  default     = false
}

variable "custom_sql_scripts_bucket" {
  description = "GCS bucket name containing custom SQL scripts (without gs:// prefix, e.g., 'my-bucket'). Only used when enable_custom_sql_scripts is true. {{UIMeta group=0 order=12003 updatesafe }}"
  type        = string
  default     = ""
}

variable "custom_sql_scripts_path" {
  description = "Path prefix in GCS bucket for SQL scripts (e.g., 'scripts/init/'). Scripts will be executed in alphabetical order. Name scripts with numeric prefixes for ordering (e.g., 001_schema.sql, 002_data.sql). {{UIMeta group=0 order=12004 updatesafe }}"
  type        = string
  default     = ""
}

# ===========================
# SECTION 13: Observability & Alerting
# ===========================

variable "uptime_check_config" {
  description = "Uptime check configuration. Monitors service availability and sends alerts on failures. {{UIMeta group=0 order=1301 updatesafe }}"
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
  description = "Custom alert policies. Define metric-based alerts for your application (e.g., error rates, latency). {{UIMeta group=0 order=1302 updatesafe }}"
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
