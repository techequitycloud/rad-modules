# ===========================
# Main Configuration
# ===========================

# Get project information
data "google_project" "project" {
  project_id = var.existing_project_id
}

# Generate random deployment ID if not provided
resource "random_id" "deployment" {
  byte_length = 4
}

# Local variables for consistent naming and configuration
locals {
  # Project information
  project = {
    project_id     = data.google_project.project.project_id
    project_number = data.google_project.project.number
    project_name   = data.google_project.project.name
  }

  # Deployment identifiers
  deployment_id = var.deployment_id != null ? var.deployment_id : random_id.deployment.hex
  tenant_id     = var.tenant_deployment_id
  random_id     = random_id.deployment.hex

  # Primary region configuration
  region = var.deployment_region

  # Multi-region configuration
  regions = length(var.deployment_regions) > 0 ? var.deployment_regions : [local.region]

  # Application configuration
  application_name         = var.application_name
  application_display_name = var.application_display_name != null ? var.application_display_name : var.application_name
  application_version      = var.application_version

  # Database configuration
  database_type          = upper(var.database_type)
  database_name_prefix   = var.application_database_name
  database_user_prefix   = var.application_database_user
  database_name_full     = "${local.database_name_prefix}_${local.tenant_id}_${local.random_id}"
  database_user_full     = "${local.database_user_prefix}_${local.tenant_id}_${local.random_id}"

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

  # Container configuration
  container_image_source = var.container_image_source

  # Container image logic:
  # 1. If custom build with CI/CD enabled: use pipeline-built image from Artifact Registry
  # 2. If custom build without CI/CD: use one-time built image
  # 3. If prebuilt selected: use provided container_image URL
  # 4. Default: use hello world placeholder
  container_image = (
    local.container_image_source == "custom" && (var.container_build_config.enabled || local.enable_cicd_trigger) ?
    "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.container_build_config.artifact_repo_name}/${local.application_name}:${local.application_version}" :
    var.container_image != null ? var.container_image :
    "gcr.io/cloudrun/hello" # Default hello world image
  )

  # NFS configuration
  nfs_enabled    = var.nfs_enabled
  nfs_mount_path = var.nfs_mount_path
  nfs_volume_name = "nfs-data-volume"
  nfs_share_path = "/share/${local.resource_prefix}"

  # Storage buckets
  storage_buckets = var.create_cloud_storage ? {
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
    for idx, vol in var.gcs_volumes :
    vol.name => {
      name          = vol.name
      bucket_name   = vol.bucket_name != null ? vol.bucket_name : try(local.storage_buckets[vol.name].name, null)
      mount_path    = vol.mount_path
      readonly      = vol.readonly
      mount_options = vol.mount_options
    }
  }

  # Environment variables (combined static and secret-based)
  static_env_vars = merge(
    var.environment_variables,
    {
      APP_NAME    = local.application_name
      APP_VERSION = local.application_version
      DB_NAME     = local.database_name_full
      DB_USER     = local.database_user_full
      DB_PORT     = tostring(local.database_port)
    }
  )

  # Network configuration
  network_name       = var.network_name
  network_tags       = var.network_tags
  vpc_egress_setting = var.vpc_egress_setting
  ingress_settings   = var.ingress_settings

  # Service accounts (will be populated by data sources)
  # Handle both null and empty string cases
  cloudrun_sa   = var.cloudrun_service_account != null && var.cloudrun_service_account != "" ? var.cloudrun_service_account : "cloudrun-sa"
  cloudbuild_sa = var.cloudbuild_service_account != null && var.cloudbuild_service_account != "" ? var.cloudbuild_service_account : "cloudbuild-sa"
  cloudsql_sa   = var.cloudsql_service_account != null && var.cloudsql_service_account != "" ? var.cloudsql_service_account : "cloudsql-sa"

  # Monitoring configuration
  configure_monitoring = var.configure_monitoring
  uptime_check_enabled = var.uptime_check_config.enabled && var.configure_monitoring

  # Feature flags
  configure_environment = var.configure_environment
  enable_custom_build   = var.container_build_config.enabled && local.container_image_source == "custom"

  # CI/CD Configuration
  enable_cicd_trigger = var.enable_cicd_trigger && var.github_repository_url != null
  github_repo_url     = var.github_repository_url
  github_token_secret = var.github_token_secret_name

  # Parse GitHub repository URL to extract owner and name
  github_repo_parts = local.github_repo_url != null ? split("/", trimprefix(trimprefix(local.github_repo_url, "https://github.com/"), "http://github.com/")) : []
  github_repo_owner = length(local.github_repo_parts) >= 2 ? local.github_repo_parts[0] : null
  github_repo_name  = length(local.github_repo_parts) >= 2 ? local.github_repo_parts[1] : null

  # CI/CD trigger configuration
  cicd_trigger_name = var.cicd_trigger_config.trigger_name != null ? var.cicd_trigger_config.trigger_name : "${local.resource_prefix}-cicd-trigger"

  # Labels
  common_labels = merge(
    var.resource_labels != null ? var.resource_labels : {},
    {
      application  = local.application_name
      deployment   = local.deployment_id
      tenant       = local.tenant_id
      managed-by   = "terraform"
      module       = "webapp"
    }
  )
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
