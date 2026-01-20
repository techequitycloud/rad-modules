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
  # 2. Coalesced Configuration
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
  application_version      = var.application_version

  # Database configuration
  database_type             = local.final_database_type
  application_database_name = local.final_database_name
  application_database_user = local.final_database_user

  database_name_full     = "${local.application_database_name}_${local.tenant_id}_${local.random_id}"
  database_user_full     = "${local.application_database_user}_${local.tenant_id}_${local.random_id}"

  # Determine database port based on type
  database_port = (
    contains(["MYSQL", "MYSQL_5_6", "MYSQL_5_7", "MYSQL_8_0"], local.database_type) ? 3306 :
    contains(["POSTGRES", "POSTGRESQL", "POSTGRES_9_6", "POSTGRES_10", "POSTGRES_11", "POSTGRES_12", "POSTGRES_13", "POSTGRES_14", "POSTGRES_15"], local.database_type) ? 5432 :
    contains(["SQLSERVER", "SQLSERVER_2017_STANDARD", "SQLSERVER_2017_ENTERPRISE", "SQLSERVER_2019_STANDARD", "SQLSERVER_2019_ENTERPRISE"], local.database_type) ? 1433 :
    3306 # Default to MySQL port
  )

  # Determine database client type for scripts
  database_client_type = (
    contains(["MYSQL", "MYSQL_5_6", "MYSQL_5_7", "MYSQL_8_0"], local.database_type) ? "MYSQL" :
    contains(["POSTGRES", "POSTGRESQL", "POSTGRES_9_6", "POSTGRES_10", "POSTGRES_11", "POSTGRES_12", "POSTGRES_13", "POSTGRES_14", "POSTGRES_15"], local.database_type) ? "POSTGRES" :
    contains(["SQLSERVER", "SQLSERVER_2017_STANDARD", "SQLSERVER_2017_ENTERPRISE", "SQLSERVER_2019_STANDARD", "SQLSERVER_2019_ENTERPRISE"], local.database_type) ? "SQLSERVER" :
    "MYSQL" # Default
  )

  # Resource naming
  resource_prefix = "app${local.application_name}${local.tenant_id}${local.random_id}"

  # Cloud Run service name
  service_name = local.resource_prefix

  # Container Config
  container_image_source = local.final_container_image_source

  # Default Container Build Config
  container_build_config = var.container_build_config != null ? var.container_build_config : {
    enabled            = false
    dockerfile_path    = "Dockerfile"
    dockerfile_content = null
    context_path       = "."
    build_args         = {}
    artifact_repo_name = "webapp-repo"
  }

  # Scoped resource names for multi-tenancy
  artifact_repo_id = "${local.tenant_id}-${local.deployment_id}-${local.container_build_config.artifact_repo_name}"

  # CI/CD Configuration
  enable_cicd_trigger = var.enable_cicd_trigger && var.github_repository_url != null
  github_token_secret = "${var.github_token_secret_name}-${local.tenant_id}"

  # Container image logic:
  container_image = (
    local.container_image_source == "custom" && local.container_build_config.enabled && !local.enable_cicd_trigger ?
    "${local.region}-docker.pkg.dev/${local.project.project_id}/${local.artifact_repo_id}/${local.application_name}:${local.application_version}" :
    local.final_container_image != "" ? local.final_container_image : "gcr.io/cloudrun/hello"
  )

  container_port         = local.final_container_port
  container_resources    = local.final_container_resources

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

  create_cloud_storage       = (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? false : var.create_cloud_storage # N8N handles own storage

  # Storage buckets
  storage_buckets = local.create_cloud_storage ? {
    for bucket in var.storage_buckets :
    bucket.name_suffix => {
      name                     = "${local.resource_prefix}-${bucket.name_suffix}"
      location                 = bucket.location
      storage_class            = bucket.storage_class
      force_destroy            = bucket.force_destroy
      versioning_enabled       = bucket.versioning_enabled
      lifecycle_rules          = bucket.lifecycle_rules
      public_access_prevention = bucket.public_access_prevention
    }
  } : {}

  # GCS volumes
  gcs_volumes = {
    for idx, vol in local.final_gcs_volumes :
    vol.name => {
      name          = vol.name
      bucket_name   = vol.bucket_name != null ? vol.bucket_name : try(local.storage_buckets[vol.name].name, null)
      mount_path    = vol.mount_path
      readonly      = vol.readonly
      mount_options = vol.mount_options
    }
  }

  # Dynamic Environment Variables for Presets
  preset_env_vars = merge(
    (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? {
      N8N_PORT                 = "5678"
      N8N_PROTOCOL             = "https"
      N8N_DIAGNOSTICS_ENABLED  = "true"
      N8N_METRICS              = "true"
      DB_TYPE                  = "postgresdb"
      DB_POSTGRESDB_DATABASE   = local.database_name_full
      DB_POSTGRESDB_USER       = local.database_user_full
      DB_POSTGRESDB_HOST       = local.db_internal_ip
      N8N_DEFAULT_BINARY_DATA_MODE = "filesystem"
      N8N_S3_ENDPOINT              = "https://storage.googleapis.com"
      N8N_S3_BUCKET_NAME           = try(google_storage_bucket.n8n_storage[0].name, "")
      N8N_S3_REGION                = var.deployment_region
    } : {},
    (var.deploy_app_preset == "wordpress" || var.application_module == "wordpress") ? {
      WORDPRESS_DB_NAME = local.database_name_full
      WORDPRESS_DB_USER = local.database_user_full
      WORDPRESS_DB_HOST = local.db_internal_ip
      WORDPRESS_DEBUG   = "false"
    } : {},
    (var.deploy_app_preset == "openemr" || var.application_module == "openemr") ? {
      MYSQL_DATABASE = local.database_name_full
      MYSQL_USER     = local.database_user_full
      MYSQL_HOST     = local.db_internal_ip
      MYSQL_PORT     = "3306"
      OE_USER        = "admin"
      OE_PASS        = "admin"
      MANUAL_SETUP   = "no"
    } : {}
  )

  # Environment variables (combined static and secret-based)
  static_env_vars = merge(
    var.environment_variables, # User input
    local.preset_env_vars,     # Preset overrides
    {
      APP_NAME    = local.application_name
      APP_VERSION = local.application_version
      DB_NAME     = local.database_name_full
      DB_USER     = local.database_user_full
      DB_PORT     = tostring(local.database_port)
    }
  )

  preset_secret_env_vars = merge(
    (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? {
      N8N_S3_ACCESS_KEY      = try(google_secret_manager_secret.storage_access_key[0].secret_id, "")
      N8N_S3_ACCESS_SECRET   = try(google_secret_manager_secret.storage_secret_key[0].secret_id, "")
      N8N_ENCRYPTION_KEY     = try(google_secret_manager_secret.encryption_key[0].secret_id, "")
    } : {},
    (var.deploy_app_preset == "openemr" || var.application_module == "openemr") ? {
      MYSQL_ROOT_PASS = "${local.db_instance_name}-root-password"
    } : {}
  )

  secret_environment_variables = merge(var.secret_environment_variables, local.preset_secret_env_vars)

  # Secret environment variables (process secret names to find versions)
  secret_env_var_map = {
    for k, v in local.secret_environment_variables : k => v
  }

  # Service accounts
  # Inject N8N SA if active
  cloudrun_sa_input = (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? google_service_account.n8n_sa[0].email : var.cloudrun_service_account
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
  initialization_jobs        = var.initialization_jobs

  cicd_trigger_config        = var.cicd_trigger_config

  enable_backup_import       = var.enable_backup_import
  backup_source              = var.backup_source
  backup_uri                 = var.backup_uri
  backup_format              = var.backup_format

  enable_gdrive_backup_import = var.enable_gdrive_backup_import
  gdrive_backup_file_id       = var.gdrive_backup_file_id
  gdrive_backup_format        = var.gdrive_backup_format

  enable_gcs_backup_import    = var.enable_gcs_backup_import
  gcs_backup_uri              = var.gcs_backup_uri
  gcs_backup_format           = var.gcs_backup_format

  enable_postgres_extensions  = var.enable_postgres_extensions
  postgres_extensions         = var.postgres_extensions

  enable_mysql_plugins        = var.enable_mysql_plugins
  mysql_plugins               = var.mysql_plugins

  enable_custom_sql_scripts   = var.enable_custom_sql_scripts
  custom_sql_scripts_bucket   = var.custom_sql_scripts_bucket
  custom_sql_scripts_path     = var.custom_sql_scripts_path
  custom_sql_scripts_use_root = var.custom_sql_scripts_use_root

  alert_policies              = var.alert_policies
  uptime_check_config         = var.uptime_check_config
  configure_environment       = var.configure_environment
  application_description     = var.application_description
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
}

# ==============================================================================
# N8N SPECIFIC RESOURCES
# ==============================================================================
resource "google_service_account" "n8n_sa" {
  count        = (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? 1 : 0
  account_id   = "${local.wrapper_prefix}-sa"
  display_name = "N8N Service Account"
  project      = var.existing_project_id
}

resource "google_storage_bucket" "n8n_storage" {
  count         = (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? 1 : 0
  name          = "${local.wrapper_prefix}-storage"
  location      = var.deployment_region
  force_destroy = true
  project       = var.existing_project_id
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "storage_admin" {
  count  = (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? 1 : 0
  bucket = google_storage_bucket.n8n_storage[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.n8n_sa[0].email}"
}

resource "google_storage_hmac_key" "n8n_key" {
  count                 = (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? 1 : 0
  service_account_email = google_service_account.n8n_sa[0].email
  project               = var.existing_project_id
}

resource "google_secret_manager_secret" "storage_access_key" {
  count     = (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? 1 : 0
  secret_id = "${local.wrapper_prefix}-access-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "storage_access_key" {
  count       = (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? 1 : 0
  secret      = google_secret_manager_secret.storage_access_key[0].id
  secret_data = google_storage_hmac_key.n8n_key[0].access_id
}

resource "google_secret_manager_secret" "storage_secret_key" {
  count     = (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? 1 : 0
  secret_id = "${local.wrapper_prefix}-secret-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "storage_secret_key" {
  count       = (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? 1 : 0
  secret      = google_secret_manager_secret.storage_secret_key[0].id
  secret_data = google_storage_hmac_key.n8n_key[0].secret
}

resource "random_password" "encryption_key" {
  count   = (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? 1 : 0
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "encryption_key" {
  count     = (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? 1 : 0
  secret_id = "${local.wrapper_prefix}-encryption-key"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "encryption_key" {
  count       = (var.deploy_app_preset == "n8n" || var.application_module == "n8n") ? 1 : 0
  secret      = google_secret_manager_secret.encryption_key[0].id
  secret_data = random_password.encryption_key[0].result
}

# Django Post-Deployment Update (CSRF Origin)
resource "null_resource" "update_csrf_origin" {
  count = (var.deploy_app_preset == "django" || var.application_module == "django") ? 1 : 0

  triggers = {
    service_id = local.service_name
  }

  provisioner "local-exec" {
    command = <<CMD
      IMPERSONATE_FLAG=""
      if [ -n "${var.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${var.impersonation_service_account}"
      fi

      SERVICE_NAME="${local.service_name}"
      REGION="${local.region}"
      PROJECT="${local.project.project_id}"

      if [ -n "$SERVICE_NAME" ]; then
        URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT --format 'value(uri)')
        gcloud run services update $SERVICE_NAME \
          --region $REGION \
          --project $PROJECT \
          --set-env-vars CLOUDRUN_SERVICE_URLS=$URL \
          $IMPERSONATE_FLAG
      fi
    CMD
  }
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
