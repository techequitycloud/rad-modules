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
  application_display_name = local.final_application_display_name
  application_version      = local.final_application_version

  # Database configuration
  database_type             = upper(local.final_database_type)
  application_database_name = local.final_application_database_name
  application_database_user = local.final_application_database_user

  database_name_full     = replace("${local.application_database_name}_${local.tenant_id}_${local.random_id}", "-", "_")
  database_user_full     = replace("${local.application_database_user}_${local.tenant_id}_${local.random_id}", "-", "_")

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
  _base_container_build_config = local.module_container_build_config != null ? local.module_container_build_config : {
      enabled            = false
      dockerfile_path    = "Dockerfile"
      dockerfile_content = null
      context_path       = "."
      build_args         = {}
      artifact_repo_name = "cloudrunapp-repo"
  }

  # Inject APP_VERSION into build_args for custom builds
  container_build_config = merge(local._base_container_build_config, {
    build_args = merge(
      try(local._base_container_build_config.build_args, {}),
      {
        APP_VERSION = local.application_version
      }
    )
  })

  # Scoped resource names for multi-tenancy
  artifact_repo_id = "${local.application_name}${local.tenant_id}${local.deployment_id}-repo"

  # CI/CD Configuration
  enable_cicd_trigger = var.enable_cicd_trigger && var.github_repository_url != null
  github_token_secret = var.github_token_secret_name != null ? "${var.github_token_secret_name}-${local.tenant_id}" : null
  enable_image_mirroring = local.final_enable_image_mirroring

  # Determine source image for mirroring (Prebuilt or Custom Build Artifact)
  mirror_source_image = (
    local.container_image_source == "custom" && local.container_build_config.enabled && !local.enable_cicd_trigger ?
    "${local.region}-docker.pkg.dev/${local.project.project_id}/${local.artifact_repo_id}/${local.application_name}:${local.application_version}" :
    local.final_container_image
  )

  _mirror_image_parts    = split(":", local.mirror_source_image)
  mirror_image_tag       = length(local._mirror_image_parts) > 1 ? local._mirror_image_parts[length(local._mirror_image_parts) - 1] : "latest"

  # Construct target image URL in Artifact Registry
  mirror_target_image    = "${local.region}-docker.pkg.dev/${local.project.project_id}/${local.artifact_repo_id}/${local.application_name}:${local.mirror_image_tag}"

  # Container image logic:
  container_image = (
    local.container_image_source == "custom" && local.container_build_config.enabled && !local.enable_cicd_trigger ?
      (local.enable_image_mirroring ? local.mirror_target_image : "${local.region}-docker.pkg.dev/${local.project.project_id}/${local.artifact_repo_id}/${local.application_name}:${local.application_version}") :
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

  create_cloud_storage       = var.create_cloud_storage

  # Preset Storage Buckets
  preset_storage_buckets = concat(
    local.module_storage_buckets,
  )

  # Combined Storage Buckets
  all_storage_buckets = concat(var.storage_buckets, local.preset_storage_buckets)

  # Storage buckets
  storage_buckets = local.create_cloud_storage ? {
    for bucket in local.all_storage_buckets :
    bucket.name_suffix => {
      name                        = try(bucket.name, "${local.resource_prefix}-${bucket.name_suffix}")
      location                    = try(bucket.location, var.deployment_region)
      storage_class               = try(bucket.storage_class, "STANDARD")
      force_destroy               = try(bucket.force_destroy, true)
      versioning_enabled          = try(bucket.versioning_enabled, false)
      lifecycle_rules             = try(bucket.lifecycle_rules, [])
      public_access_prevention    = try(bucket.public_access_prevention, "enforced")
      uniform_bucket_level_access = try(bucket.uniform_bucket_level_access, false)
      soft_delete_retention_seconds = try(bucket.soft_delete_retention_seconds, 0)
    }
  } : {}

  # GCS volumes
  gcs_volumes = {
    for idx, vol in local.final_gcs_volumes :
    vol.name => {
      name          = vol.name
      bucket_name   = (vol.bucket_name != null && vol.bucket_name != "") ? vol.bucket_name : (
        try(local.storage_buckets[vol.name].name, null)
      )
      mount_path    = vol.mount_path
      readonly      = vol.readonly
      mount_options = vol.mount_options
    }
  }

  # Dynamic Environment Variables for Modules (these depend on resources generated in this main.tf)
  preset_env_vars = merge(
    try(local.module_env_vars, {}),
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
      DB_HOST     = try(local.preset_env_vars["DB_HOST"], local.db_internal_ip)
      DB_IP       = local.db_internal_ip
    }
  )

  preset_secret_env_vars = merge(
    # Universal DB_PASSWORD injection for all modules (if DB exists)
    local.sql_server_exists ? {
      DB_PASSWORD = try(google_secret_manager_secret.db_password[0].secret_id, "")
    } : {},
    local.module_secret_env_vars,
  )

  secret_environment_variables = merge(
    { for k, v in var.secret_environment_variables : k => v if v != "" },
    local.preset_secret_env_vars
  )

  secret_env_var_map = local.secret_environment_variables

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
  container_protocol          = "http1"
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
  cicd_trigger_name = "${local.tenant_id}-${local.deployment_id}-${local.application_name}-trigger"

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
      module       = "cloudrunapp"
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
    google_artifact_registry_repository.application_image,
    # Wait for custom build if needed
    null_resource.build_and_push_application_image
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
