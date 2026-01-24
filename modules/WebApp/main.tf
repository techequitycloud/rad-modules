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
# Main Configuration
# ===========================

# Get project information
data "google_project" "project" {
  project_id = var.existing_project_id
}

# Generate random deployment ID if not provided (for module internal use)
resource "random_id" "deployment" {
  byte_length = 4
}

# Generate wrapper-specific random ID for wrapper resources (like N8N SA) to avoid cycles
resource "random_id" "wrapper_deployment" {
  byte_length = 4
}

# Local variables for consistent naming and configuration
locals {
  
  # ===========================
  # 1. Coalesced Configuration
  # ===========================

  # Project information
  project = {
    project_id     = data.google_project.project.project_id
    project_number = data.google_project.project.number
    project_name   = data.google_project.project.name
  }

  # Deployment identifiers
  # Use wrapper's random ID for consistent naming across all resources in this module
  random_id     = random_id.wrapper_deployment.hex
  deployment_id = var.deployment_id != null ? var.deployment_id : local.random_id
  tenant_id     = var.tenant_deployment_id

  wrapper_prefix = "app${local.application_name}${local.tenant_id}${local.random_id}"

  # Primary region configuration
  region = var.deployment_region

  # Multi-region configuration
  regions = length(var.deployment_regions) > 0 ? var.deployment_regions : [local.region]

  # Application configuration
  application_name         = local.final_application_name
  application_display_name = var.application_display_name != null ? var.application_display_name : local.application_name
  application_version      = local.final_application_version

  # Database configuration
  database_type             = upper(local.final_database_type)
  application_database_name = local.final_application_database_name
  application_database_user = local.final_application_database_user

  database_name_full     = "${local.application_database_name}_${local.tenant_id}_${local.random_id}"
  database_user_full     = "${local.application_database_user}_${local.tenant_id}_${local.random_id}"

  # ✅ UPDATED: Determine database port based on type (added POSTGRES_16)
  database_port = (
    local.database_type == "NONE" ? 0 :
    contains(["MYSQL", "MYSQL_5_6", "MYSQL_5_7", "MYSQL_8_0"], local.database_type) ? 3306 :
    contains(["POSTGRES", "POSTGRESQL", "POSTGRES_9_6", "POSTGRES_10", "POSTGRES_11", "POSTGRES_12", "POSTGRES_13", "POSTGRES_14", "POSTGRES_15", "POSTGRES_16"], local.database_type) ? 5432 :
    contains(["SQLSERVER", "SQLSERVER_2017_STANDARD", "SQLSERVER_2017_ENTERPRISE", "SQLSERVER_2019_STANDARD", "SQLSERVER_2019_ENTERPRISE"], local.database_type) ? 1433 :
    3306 # Default to MySQL port
  )

  # ✅ UPDATED: Determine database client type for scripts (added POSTGRES_16)
  database_client_type = (
    local.database_type == "NONE" ? "NONE" :
    contains(["MYSQL", "MYSQL_5_6", "MYSQL_5_7", "MYSQL_8_0"], local.database_type) ? "MYSQL" :
    contains(["POSTGRES", "POSTGRESQL", "POSTGRES_9_6", "POSTGRES_10", "POSTGRES_11", "POSTGRES_12", "POSTGRES_13", "POSTGRES_14", "POSTGRES_15", "POSTGRES_16"], local.database_type) ? "POSTGRES" :
    contains(["SQLSERVER", "SQLSERVER_2017_STANDARD", "SQLSERVER_2017_ENTERPRISE", "SQLSERVER_2019_STANDARD", "SQLSERVER_2019_ENTERPRISE"], local.database_type) ? "SQLSERVER" :
    "MYSQL" # Default
  )

  # ✅ NEW: PostgreSQL vs MySQL socket paths
  cloudsql_socket_path = (
    local.database_type == "NONE" ? "" :
    contains(["POSTGRES", "POSTGRESQL", "POSTGRES_9_6", "POSTGRES_10", "POSTGRES_11", "POSTGRES_12", "POSTGRES_13", "POSTGRES_14", "POSTGRES_15", "POSTGRES_16"], local.database_type) ? 
    "/var/run/postgresql" : 
    "/var/run/mysqld"
  )

  # ✅ Calculate predictable Cloud Run URL for Moodle
  # Format: https://<SERVICE_NAME>-<PROJECT_NUMBER>.<REGION>.run.app
  # This is deterministic and can be calculated before deployment
  predicted_service_url = "https://${local.service_name}-${local.project.project_number}.${local.region}.run.app"

  # Resource naming
  resource_prefix = "app${local.application_name}${local.tenant_id}${local.random_id}"

  # Cloud Run service name
  service_name = local.resource_prefix

  # Container Config
  container_image_source = local.final_container_image_source

  # Default Container Build Config
  container_build_config = var.container_build_config != null ? var.container_build_config : (
    local.module_container_build_config != null ? local.module_container_build_config : {
      enabled            = false
      dockerfile_path    = "Dockerfile"
      dockerfile_content = null
      context_path       = "."
      build_args         = {}
      artifact_repo_name = "webapp-repo"
    }
  )

  # Scoped resource names for multi-tenancy
  artifact_repo_id = "${local.application_name}${local.tenant_id}${local.deployment_id}-repo"

  # CI/CD Configuration
  enable_cicd_trigger = var.enable_cicd_trigger && var.github_repository_url != null
  github_token_secret = "${var.github_token_secret_name}-${local.tenant_id}"

  # ✅ UPDATED: Image Mirroring Configuration (disabled for Moodle - Bitnami deprecated Aug 28, 2025)
  # Using lthub/moodle:latest which works directly from Docker Hub
  enable_image_mirroring = local.final_enable_image_mirroring
  mirror_source_image    = local.final_container_image

  # Extract tag from source image (e.g., "4" from "bitnami/moodle:4"), default to "latest"
  _mirror_image_parts    = split(":", local.mirror_source_image)
  mirror_image_tag       = length(local._mirror_image_parts) > 1 ? local._mirror_image_parts[length(local._mirror_image_parts) - 1] : "latest"

  # Construct target image URL in Artifact Registry
  mirror_target_image    = "${local.region}-docker.pkg.dev/${local.project.project_id}/${local.artifact_repo_id}/${local.application_name}:${local.mirror_image_tag}"

  # Container image logic:
  container_image = (
    local.container_image_source == "custom" && local.container_build_config.enabled && !local.enable_cicd_trigger ?
    "${local.region}-docker.pkg.dev/${local.project.project_id}/${local.artifact_repo_id}/${local.application_name}:${local.application_version}" :
    local.enable_image_mirroring ? local.mirror_target_image :
    local.final_container_image != "" ? local.final_container_image : "gcr.io/cloudrun/hello"
  )

  container_port         = local.final_container_port
  container_resources    = local.final_container_resources

  # ✅ Container command and args (for Odoo and other apps that need custom startup)
  final_container_command = local.module_container_command
  final_container_args    = local.module_container_args

  # Scaling
  min_instance_count = local.final_min_instance_count
  max_instance_count = local.final_max_instance_count

  # Probes
  startup_probe_config = local.final_startup_probe_config
  health_check_config  = local.final_health_check_config

  # Storage & Network
  nfs_enabled                = local.final_nfs_enabled
  nfs_mount_path             = local.final_nfs_mount_path
  nfs_volume_name            = "nfs-data-volume"
  nfs_share_path             = "/share/${local.resource_prefix}"

  enable_cloudsql_volume     = local.final_enable_cloudsql_volume
  cloudsql_volume_mount_path = local.final_cloudsql_volume_mount_path

  create_cloud_storage       = var.application_module == "n8n" ? false : var.create_cloud_storage # N8N handles own storage

  # Preset Storage Buckets
  preset_storage_buckets = concat(
    var.application_module == "odoo" ? [
      {
        name_suffix              = "odoo-addons-volume"
        location                 = var.deployment_region
        storage_class            = "STANDARD"
        force_destroy            = true
        versioning_enabled       = false
        lifecycle_rules          = []
        public_access_prevention = "inherited"
      }
    ] : [],
    var.application_module == "django" ? [
      {
        name_suffix              = "django-static"
        location                 = var.deployment_region
        storage_class            = "STANDARD"
        force_destroy            = true
        versioning_enabled       = false
        lifecycle_rules          = []
        public_access_prevention = "inherited"
      },
      {
        name_suffix              = "django-media"
        location                 = var.deployment_region
        storage_class            = "STANDARD"
        force_destroy            = true
        versioning_enabled       = false
        lifecycle_rules          = []
        public_access_prevention = "inherited"
      }
    ] : [],
    var.application_module == "wordpress" ? [
      {
        name_suffix              = "wp-uploads"
        location                 = var.deployment_region
        storage_class            = "STANDARD"
        force_destroy            = true
        versioning_enabled       = false
        lifecycle_rules          = []
        public_access_prevention = "inherited"
      }
    ] : [],
    var.application_module == "moodle" ? [
      {
        name_suffix              = "moodle-data"
        location                 = var.deployment_region
        storage_class            = "STANDARD"
        force_destroy            = true
        versioning_enabled       = false
        lifecycle_rules          = []
        public_access_prevention = "inherited"
      }
    ] : [],
    var.application_module == "n8n" ? [
      {
        name_suffix              = "n8n-data"
        location                 = var.deployment_region
        storage_class            = "STANDARD"
        force_destroy            = true
        versioning_enabled       = false
        lifecycle_rules          = []
        public_access_prevention = "inherited"
      }
    ] : [],
    var.application_module == "ghost" ? [
      {
        name_suffix              = "ghost-content"
        location                 = var.deployment_region
        storage_class            = "STANDARD"
        force_destroy            = true
        versioning_enabled       = false
        lifecycle_rules          = []
        public_access_prevention = "inherited"
      }
    ] : [],
    var.application_module == "wikijs" ? [
      {
        name_suffix              = "wikijs-storage"
        location                 = var.deployment_region
        storage_class            = "STANDARD"
        force_destroy            = true
        versioning_enabled       = false
        lifecycle_rules          = []
        public_access_prevention = "inherited"
      }
    ] : [],
    var.application_module == "medusa" ? [
      {
        name_suffix              = "medusa-uploads"
        location                 = var.deployment_region
        storage_class            = "STANDARD"
        force_destroy            = true
        versioning_enabled       = false
        lifecycle_rules          = []
        public_access_prevention = "inherited"
      }
    ] : [],
    var.application_module == "strapi" ? [
      {
        name_suffix              = "strapi-uploads"
        location                 = var.deployment_region
        storage_class            = "STANDARD"
        force_destroy            = true
        versioning_enabled       = false
        lifecycle_rules          = []
        public_access_prevention = "inherited"
      }
    ] : [],
    var.application_module == "directus" ? [
      {
        name_suffix              = "directus-uploads"
        location                 = var.deployment_region
        storage_class            = "STANDARD"
        force_destroy            = true
        versioning_enabled       = false
        lifecycle_rules          = []
        public_access_prevention = "inherited"
      }
    ] : []
  )

  # Combined Storage Buckets
  all_storage_buckets = concat(var.storage_buckets, local.preset_storage_buckets)

  # Storage buckets
  storage_buckets = local.create_cloud_storage ? {
    for bucket in local.all_storage_buckets :
    bucket.name_suffix => {
      name                     = "${local.resource_prefix}-${bucket.name_suffix}"
      location                 = bucket.location
      storage_class            = bucket.storage_class
      force_destroy            = bucket.force_destroy
      versioning_enabled       = bucket.versioning_enabled
      lifecycle_rules          = bucket.lifecycle_rules
      public_access_prevention = bucket.public_access_prevention
      uniform_bucket_level_access = try(bucket.uniform_bucket_level_access, false)
    }
  } : {}

  # GCS volumes
  gcs_volumes = {
    for idx, vol in local.final_gcs_volumes :
    vol.name => {
      name          = vol.name
      bucket_name   = (vol.bucket_name != null && vol.bucket_name != "") ? vol.bucket_name : (
        var.application_module == "n8n" && vol.name == "n8n-data" ? try(google_storage_bucket.n8n_storage[0].name, null) :
        try(local.storage_buckets[vol.name].name, null)
      )
      mount_path    = vol.mount_path
      readonly      = vol.readonly
      mount_options = vol.mount_options
    }
  }

  # Dynamic Environment Variables for Modules (these depend on resources generated in this main.tf)
  preset_env_vars = merge(
    var.application_module == "n8n" ? {
      N8N_PORT                 = "5678"
      N8N_PROTOCOL             = "https"
      N8N_DIAGNOSTICS_ENABLED  = "true"
      N8N_METRICS              = "true"
      DB_TYPE                  = "postgresdb"
      DB_POSTGRESDB_DATABASE   = local.database_name_full
      DB_POSTGRESDB_USER       = local.database_user_full
      DB_POSTGRESDB_HOST       = local.db_internal_ip
      N8N_DEFAULT_BINARY_DATA_MODE = "filesystem"
      WEBHOOK_URL                  = local.predicted_service_url
      N8N_EDITOR_BASE_URL          = local.predicted_service_url
    } : {},
    var.application_module == "odoo" ? {
      HOST    = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
      DB_HOST = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
      USER    = local.database_user_full
      DB_PORT = "5432"
      PGPORT  = "5432"
    } : {},
    var.application_module == "django" ? {
      CLOUDRUN_SERVICE_URLS = local.predicted_service_url
    } : {},
    var.application_module == "wordpress" ? {
      WORDPRESS_DB_NAME = local.database_name_full
      WORDPRESS_DB_USER = local.database_user_full
      WORDPRESS_DB_HOST = local.db_internal_ip
      WORDPRESS_DEBUG   = "false"
    } : {},
    # ✅ UPDATED: Dynamic Moodle environment variables (PostgreSQL compatible with pre-calculated URL)
    var.application_module == "moodle" ? {
      # Database connection (supports both MySQL and PostgreSQL)
      MOODLE_DB_HOST = local.db_internal_ip
      MOODLE_DB_PORT = tostring(local.database_port)
      MOODLE_DB_USER = local.database_user_full
      MOODLE_DB_NAME = local.database_name_full
      
      # Database type: "pgsql" for PostgreSQL, "mysqli" for MySQL
      MOODLE_DB_TYPE = local.database_client_type == "POSTGRES" ? "pgsql" : "mysqli"
      
      # ✅ Pre-calculated Cloud Run URL (deterministic format)
      MOODLE_WWWROOT  = local.predicted_service_url
      MOODLE_SITE_URL = local.predicted_service_url
      MOODLE_URL      = local.predicted_service_url
      APP_URL         = local.predicted_service_url
      
      # ✅ Reverse Proxy Support (CRITICAL for Cloud Run)
      ENABLE_REVERSE_PROXY = "TRUE"
      MOODLE_REVERSE_PROXY = "true"
      
      # ✅ Cron Configuration
      CRON_INTERVAL = "1"
      
      # Site configuration
      MOODLE_SITE_NAME     = "Moodle LMS"
      MOODLE_SITE_FULLNAME = "Moodle Learning Management System"
      LANGUAGE             = "en"
      MOODLE_ADMIN_USER    = "admin"
      MOODLE_ADMIN_EMAIL   = "admin@example.com"
      
      # Installation settings
      MOODLE_SKIP_INSTALL = "no"
      MOODLE_UPDATE       = "yes"
      
      # Data directory
      MOODLE_DATA_DIR = "/var/moodledata"
      DATA_PATH       = "/var/moodledata"
    } : {},
    var.application_module == "ghost" ? {
      url                            = local.predicted_service_url
      database__connection__host     = local.db_internal_ip
      database__connection__user     = local.database_user_full
      database__connection__database = local.database_name_full
      database__connection__port     = "3306"
      database__connection__socketPath = ""
    } : {},
    var.application_module == "openemr" ? {
      MYSQL_DATABASE = local.database_name_full
      MYSQL_USER     = local.database_user_full
      MYSQL_HOST     = local.db_internal_ip
      MYSQL_PORT     = "3306"
      OE_USER        = "admin"
      MANUAL_SETUP   = "no"
      BACKUP_FILEID  = local.final_backup_uri != null ? local.final_backup_uri : ""
      SWARM_MODE     = "yes"
    } : {},
    var.application_module == "medusa" ? {
      DB_HOST     = local.db_internal_ip
      DB_PORT     = "5432"
      DB_NAME     = local.database_name_full
      DB_USER     = local.database_user_full
    } : {},
    var.application_module == "strapi" ? {
      DATABASE_HOST     = local.db_internal_ip
      DATABASE_PORT     = "5432"
      DATABASE_NAME     = local.database_name_full
      DATABASE_USERNAME = local.database_user_full
      STRAPI_URL        = local.predicted_service_url
    } : {},
    var.application_module == "directus" ? {
      DB_CLIENT              = "pg"
      DB_HOST                = local.db_internal_ip
      DB_PORT                = "5432"
      DB_DATABASE            = local.database_name_full
      DB_USER                = local.database_user_full
      PUBLIC_URL             = local.predicted_service_url
      STORAGE_LOCATIONS      = "uploads"
      STORAGE_UPLOADS_DRIVER = "local"
      STORAGE_UPLOADS_ROOT   = "/mnt/directus-uploads"
      WEBSOCKETS_ENABLED     = "true"
      CORS_ENABLED           = "true"
      CORS_ORIGIN            = local.predicted_service_url
      ADMIN_EMAIL            = try(local.final_environment_variables["ADMIN_EMAIL"], "admin@example.com")
    } : {}
  )

  # Environment variables (combined static and secret-based)
  static_env_vars = merge(
    local.final_environment_variables, # User input and Module static vars
    local.preset_env_vars,             # Dynamic module vars
    {
      APP_NAME    = local.application_name
      APP_VERSION = local.application_version
      DB_NAME     = local.database_name_full
      DB_USER     = local.database_user_full
      DB_PORT     = tostring(local.database_port)
      DB_HOST     = local.db_internal_ip
      DB_IP       = local.db_internal_ip
    }
  )

  preset_secret_env_vars = merge(
    # Universal DB_PASSWORD injection for all modules (if DB exists)
    local.sql_server_exists ? {
      DB_PASSWORD = try(google_secret_manager_secret.db_password[0].secret_id, "")
    } : {},
    
    var.application_module == "n8n" ? {
      N8N_ENCRYPTION_KEY     = try(google_secret_manager_secret.encryption_key[0].secret_id, "")
      DB_POSTGRESDB_PASSWORD = try(google_secret_manager_secret.db_password[0].secret_id, "")
      N8N_SMTP_PASS          = try(google_secret_manager_secret.n8n_smtp_password[0].secret_id, "")
    } : {},
    var.application_module == "wordpress" ? {
      WORDPRESS_DB_PASSWORD = try(google_secret_manager_secret.db_password[0].secret_id, "")
    } : {},
    var.application_module == "django" ? {
      DJANGO_SUPERUSER_PASSWORD = try(google_secret_manager_secret.db_password[0].secret_id, "")
    } : {},
    var.application_module == "odoo" ? {
      ODOO_MASTER_PASS = try(google_secret_manager_secret.odoo_master_pass[0].secret_id, "")
    } : {},
    # ✅ UPDATED: Moodle secret environment variables
    var.application_module == "moodle" ? {
      MOODLE_DB_PASSWORD = try(google_secret_manager_secret.db_password[0].secret_id, "")
    } : {},
    var.application_module == "openemr" ? {
      MYSQL_ROOT_PASS = "${local.db_instance_name}-root-password"
      OE_PASS         = try(google_secret_manager_secret.openemr_admin_password[0].secret_id, "")
      MYSQL_PASS      = try(google_secret_manager_secret.db_password[0].secret_id, "")
    } : {},
    var.application_module == "ghost" ? {
      database__connection__password = try(google_secret_manager_secret.db_password[0].secret_id, "")
    } : {},
    var.application_module == "wikijs" ? {
      DB_PASS = try(google_secret_manager_secret.db_password[0].secret_id, "")
    } : {},
    var.application_module == "medusa" ? {
      DB_PASSWORD   = try(google_secret_manager_secret.db_password[0].secret_id, "")
      JWT_SECRET    = try(google_secret_manager_secret.medusa_jwt_secret[0].secret_id, "")
      COOKIE_SECRET = try(google_secret_manager_secret.medusa_cookie_secret[0].secret_id, "")
    } : {},
    var.application_module == "strapi" ? {
      DATABASE_PASSWORD   = try(google_secret_manager_secret.db_password[0].secret_id, "")
      JWT_SECRET          = try(google_secret_manager_secret.strapi_jwt_secret[0].secret_id, "")
      ADMIN_JWT_SECRET    = try(google_secret_manager_secret.strapi_admin_jwt_secret[0].secret_id, "")
      API_TOKEN_SALT      = try(google_secret_manager_secret.strapi_api_token_salt[0].secret_id, "")
      TRANSFER_TOKEN_SALT = try(google_secret_manager_secret.strapi_transfer_token_salt[0].secret_id, "")
      APP_KEYS            = try(google_secret_manager_secret.strapi_app_keys[0].secret_id, "")
    } : {},
    var.application_module == "directus" ? {
      KEY            = try(google_secret_manager_secret.directus_key[0].secret_id, "")
      SECRET         = try(google_secret_manager_secret.directus_secret[0].secret_id, "")
      ADMIN_PASSWORD = try(google_secret_manager_secret.directus_admin_password[0].secret_id, "")
      DB_PASSWORD    = try(google_secret_manager_secret.db_password[0].secret_id, "")
    } : {}
  )

  secret_environment_variables = merge(
    { for k, v in var.secret_environment_variables : k => v if v != "" },
    local.preset_secret_env_vars
  )

  # Service accounts
  # Inject N8N SA if active
  cloudrun_sa_input = var.cloudrun_service_account
  cloudrun_service_account   = local.cloudrun_sa_input != null && local.cloudrun_sa_input != "" ? local.cloudrun_sa_input : "cloudrun-sa"

  cloudbuild_service_account = var.cloudbuild_service_account != null && var.cloudbuild_service_account != "" ? var.cloudbuild_service_account : "cloudbuild-sa"
  cloudsql_service_account   = var.cloudsql_service_account

  # Pass-through Locals (Mapping var to local for consistency)
  existing_project_id        = var.existing_project_id
  agent_service_account      = var.agent_service_account
  resource_creator_identity  = var.resource_creator_identity
  resource_labels            = var.resource_labels

  timeout_seconds            = var.timeout_seconds
  service_annotations        = var.service_annotations
  trusted_users              = var.trusted_users
  initialization_jobs        = local.final_initialization_jobs

  cicd_trigger_config        = var.cicd_trigger_config

  enable_backup_import       = var.enable_backup_import

  enable_gdrive_backup_import = var.enable_gdrive_backup_import
  gdrive_backup_file_id       = var.gdrive_backup_file_id
  gdrive_backup_format        = var.gdrive_backup_format

  enable_gcs_backup_import    = var.enable_gcs_backup_import
  gcs_backup_uri              = var.gcs_backup_uri
  gcs_backup_format           = var.gcs_backup_format

  enable_postgres_extensions  = local.final_enable_postgres_extensions
  postgres_extensions         = local.final_postgres_extensions

  enable_mysql_plugins        = local.final_enable_mysql_plugins
  mysql_plugins               = local.final_mysql_plugins

  enable_custom_sql_scripts   = var.enable_custom_sql_scripts
  custom_sql_scripts_bucket   = var.custom_sql_scripts_bucket
  custom_sql_scripts_path     = var.custom_sql_scripts_path
  custom_sql_scripts_use_root = var.custom_sql_scripts_use_root

  alert_policies              = var.alert_policies
  uptime_check_config         = var.uptime_check_config
  configure_environment       = var.configure_environment
  application_description     = local.final_application_description
  execution_environment       = var.execution_environment
  service_labels              = var.service_labels
  container_protocol          = var.container_protocol
  github_app_installation_id  = var.github_app_installation_id
  database_password_length    = var.database_password_length
  secret_propagation_delay    = var.secret_propagation_delay

  # Network configuration
  network_name       = var.network_name
  network_tags       = var.network_tags
  vpc_egress_setting = var.vpc_egress_setting
  ingress_settings   = var.ingress_settings

  # Feature flags
  enable_custom_build   = local.container_build_config.enabled && local.container_image_source == "custom"

  # Parse GitHub repository URL to extract owner and name
  _github_repo_clean = var.github_repository_url != null ? trimsuffix(trimprefix(trimprefix(var.github_repository_url, "https://github.com/"), "http://github.com/"), ".git") : ""

  github_repo_parts = split("/", local._github_repo_clean)
  github_repo_owner = length(local.github_repo_parts) >= 2 ? local.github_repo_parts[0] : null
  github_repo_name  = length(local.github_repo_parts) >= 2 ? local.github_repo_parts[1] : null

  # Normalized GitHub repository URL required for Cloud Build v2
  github_repo_url = local.github_repo_owner != null && local.github_repo_name != null ? "https://github.com/${local.github_repo_owner}/${local.github_repo_name}.git" : null

  # CI/CD trigger configuration (tenant-first for easier identification)
  cicd_trigger_name = local.cicd_trigger_config.trigger_name != null ? local.cicd_trigger_config.trigger_name : "${local.tenant_id}-${local.deployment_id}-${local.application_name}-trigger"

  # GitHub repository resource name scoped to tenant and deployment (tenant-first for easier identification)
  github_repository_resource_name = "${local.tenant_id}-${local.deployment_id}-${local.application_name}-repo"

  # Labels
  common_labels = merge(
    local.resource_labels != null ? local.resource_labels : {},
    {
      application  = local.application_name
      deployment   = local.deployment_id
      tenant       = local.tenant_id
      managed-by   = "terraform"
      module       = "webapp"
    }
  )

  # ===========================
  # Compatibility & Helper Locals
  # ===========================

  # Aliases for backward compatibility and missing references
  cloudbuild_sa                 = local.cloudbuild_service_account
  cloudrun_sa                   = local.cloudrun_service_account

  # Monitoring configuration
  uptime_check_enabled = try(local.uptime_check_config.enabled, false)
  configure_monitoring = (
    length(local.trusted_users) > 0 ||
    length(local.alert_policies) > 0 ||
    local.uptime_check_enabled
  )
}

# ==============================================================================
# N8N SPECIFIC RESOURCES
# ==============================================================================
resource "google_storage_bucket" "n8n_storage" {
  count         = var.application_module == "n8n" ? 1 : 0
  name          = "${local.wrapper_prefix}-storage"
  location      = var.deployment_region
  force_destroy = true
  project       = var.existing_project_id
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "n8n_cloudrun_access" {
  count  = var.application_module == "n8n" ? 1 : 0
  bucket = google_storage_bucket.n8n_storage[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.cloud_run_sa_email}"
}

resource "random_password" "n8n_smtp_password_dummy" {
  count   = var.application_module == "n8n" ? 1 : 0
  length  = 16
  special = false
}

resource "google_secret_manager_secret" "n8n_smtp_password" {
  count     = var.application_module == "n8n" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-smtp-password"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "n8n_smtp_password" {
  count       = var.application_module == "n8n" ? 1 : 0
  secret      = google_secret_manager_secret.n8n_smtp_password[0].id
  secret_data = random_password.n8n_smtp_password_dummy[0].result
}

resource "random_password" "encryption_key" {
  count   = var.application_module == "n8n" ? 1 : 0
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "encryption_key" {
  count     = var.application_module == "n8n" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-encryption-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "encryption_key" {
  count       = var.application_module == "n8n" ? 1 : 0
  secret      = google_secret_manager_secret.encryption_key[0].id
  secret_data = random_password.encryption_key[0].result
}

# ==============================================================================
# MEDUSA SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "medusa_jwt_secret" {
  count   = var.application_module == "medusa" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "medusa_jwt_secret" {
  count     = var.application_module == "medusa" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-jwt-secret"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "medusa_jwt_secret" {
  count       = var.application_module == "medusa" ? 1 : 0
  secret      = google_secret_manager_secret.medusa_jwt_secret[0].id
  secret_data = random_password.medusa_jwt_secret[0].result
}

resource "random_password" "medusa_cookie_secret" {
  count   = var.application_module == "medusa" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "medusa_cookie_secret" {
  count     = var.application_module == "medusa" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-cookie-secret"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "medusa_cookie_secret" {
  count       = var.application_module == "medusa" ? 1 : 0
  secret      = google_secret_manager_secret.medusa_cookie_secret[0].id
  secret_data = random_password.medusa_cookie_secret[0].result
}

# ==============================================================================
# STRAPI SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "strapi_jwt_secret" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_jwt_secret" {
  count     = var.application_module == "strapi" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-jwt-secret"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_jwt_secret" {
  count       = var.application_module == "strapi" ? 1 : 0
  secret      = google_secret_manager_secret.strapi_jwt_secret[0].id
  secret_data = random_password.strapi_jwt_secret[0].result
}

resource "random_password" "strapi_admin_jwt_secret" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_admin_jwt_secret" {
  count     = var.application_module == "strapi" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-admin-jwt-secret"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_admin_jwt_secret" {
  count       = var.application_module == "strapi" ? 1 : 0
  secret      = google_secret_manager_secret.strapi_admin_jwt_secret[0].id
  secret_data = random_password.strapi_admin_jwt_secret[0].result
}

resource "random_password" "strapi_api_token_salt" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_api_token_salt" {
  count     = var.application_module == "strapi" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-api-token-salt"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_api_token_salt" {
  count       = var.application_module == "strapi" ? 1 : 0
  secret      = google_secret_manager_secret.strapi_api_token_salt[0].id
  secret_data = random_password.strapi_api_token_salt[0].result
}

resource "random_password" "strapi_transfer_token_salt" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_transfer_token_salt" {
  count     = var.application_module == "strapi" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-transfer-token-salt"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_transfer_token_salt" {
  count       = var.application_module == "strapi" ? 1 : 0
  secret      = google_secret_manager_secret.strapi_transfer_token_salt[0].id
  secret_data = random_password.strapi_transfer_token_salt[0].result
}

resource "random_password" "strapi_app_key_1" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}
resource "random_password" "strapi_app_key_2" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}
resource "random_password" "strapi_app_key_3" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}
resource "random_password" "strapi_app_key_4" {
  count   = var.application_module == "strapi" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "strapi_app_keys" {
  count     = var.application_module == "strapi" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-app-keys"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "strapi_app_keys" {
  count       = var.application_module == "strapi" ? 1 : 0
  secret      = google_secret_manager_secret.strapi_app_keys[0].id
  secret_data = "${random_password.strapi_app_key_1[0].result},${random_password.strapi_app_key_2[0].result},${random_password.strapi_app_key_3[0].result},${random_password.strapi_app_key_4[0].result}"
}

# ==============================================================================
# IMAGE MIRRORING RESOURCES
# ==============================================================================
resource "null_resource" "mirror_image" {
  count = local.enable_image_mirroring ? 1 : 0

  triggers = {
    source_image = local.mirror_source_image
    target_image = local.mirror_target_image
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/core/mirror-image.sh ${local.project.project_id} ${local.region} ${local.artifact_repo_id} ${local.mirror_source_image} ${local.application_name} ${local.mirror_image_tag} \"${local.impersonation_service_account}\""
  }

  depends_on = [
    # Artifact registry must exist
    google_artifact_registry_repository.application_image
  ]
}

# Output deployment information for debugging
output "deployment_info" {
  description = "Deployment information"
  value = {
    deployment_id    = local.deployment_id
    tenant_id        = local.tenant_id
    resource_prefix  = local.resource_prefix
    service_name     = local.service_name
    database_type    = local.database_type
    database_port    = local.database_port
    container_image  = local.container_image
    regions          = local.regions
  }
}

# ==============================================================================
# OPENEMR SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "openemr_admin_password" {
  count   = var.application_module == "openemr" ? 1 : 0
  length  = 20
  special = false
}

resource "google_secret_manager_secret" "openemr_admin_password" {
  count     = var.application_module == "openemr" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-admin-password"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "openemr_admin_password" {
  count       = var.application_module == "openemr" ? 1 : 0
  secret      = google_secret_manager_secret.openemr_admin_password[0].id
  secret_data = random_password.openemr_admin_password[0].result
}

# ==============================================================================
# DIRECTUS SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "directus_key" {
  count   = var.application_module == "directus" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "directus_key" {
  count     = var.application_module == "directus" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "directus_key" {
  count       = var.application_module == "directus" ? 1 : 0
  secret      = google_secret_manager_secret.directus_key[0].id
  secret_data = random_password.directus_key[0].result
}

resource "random_password" "directus_secret" {
  count   = var.application_module == "directus" ? 1 : 0
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "directus_secret" {
  count     = var.application_module == "directus" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-secret-app"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "directus_secret" {
  count       = var.application_module == "directus" ? 1 : 0
  secret      = google_secret_manager_secret.directus_secret[0].id
  secret_data = random_password.directus_secret[0].result
}

resource "random_password" "directus_admin_password" {
  count   = var.application_module == "directus" ? 1 : 0
  length  = 20
  special = false
}

resource "google_secret_manager_secret" "directus_admin_password" {
  count     = var.application_module == "directus" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-admin-password"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "directus_admin_password" {
  count       = var.application_module == "directus" ? 1 : 0
  secret      = google_secret_manager_secret.directus_admin_password[0].id
  secret_data = random_password.directus_admin_password[0].result
}

# ==============================================================================
# ODOO SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "odoo_master_pass" {
  count   = var.application_module == "odoo" ? 1 : 0
  length  = 16
  special = false
}

resource "google_secret_manager_secret" "odoo_master_pass" {
  count     = var.application_module == "odoo" ? 1 : 0
  secret_id = "${local.wrapper_prefix}-master-pass"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "odoo_master_pass" {
  count       = var.application_module == "odoo" ? 1 : 0
  secret      = google_secret_manager_secret.odoo_master_pass[0].id
  secret_data = random_password.odoo_master_pass[0].result
}
