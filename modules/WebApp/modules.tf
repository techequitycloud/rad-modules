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

#########################################################################
# Application Modules - Main Configuration
#
# This file loads individual module configurations from the modules/
# directory and provides the selection logic for using presets.
#
# Directory Structure:
#   modules/
#   ├── odoo/variables.tf
#   ├── wordpress/variables.tf
#   ├── moodle/variables.tf
#   └── ... (one directory per application)
#
# Each module defines its own configuration in isolation, making it
# easy to maintain, update, and add new modules without affecting
# existing ones.
#########################################################################

#########################################################################
# Load Individual Preset Configurations
#########################################################################

# Each module is defined in its own directory under modules/
# This provides clean separation and makes it easy to maintain
module "odoo_module" {
  source = "./modules/odoo"
}

module "wordpress_module" {
  source = "./modules/wordpress"
}

module "moodle_module" {
  source = "./modules/moodle"
}

module "cyclos_module" {
  source = "./modules/cyclos"
}

module "django_module" {
  source = "./modules/django"
}

module "openemr_module" {
  source = "./modules/openemr"
}

module "n8n_module" {
  source = "./modules/n8n"
}

module "nextcloud_module" {
  source = "./modules/nextcloud"
}

module "ghost_module" {
  source = "./modules/ghost"
}

module "wikijs_module" {
  source = "./modules/wikijs"
}

module "plane_module" {
  source = "./modules/plane"
}

module "medusa_module" {
  source = "./modules/medusa"
}

module "payload_module" {
  source = "./modules/payload"
}

module "invoiceninja_module" {
  source = "./modules/invoiceninja"
}
  
module "strapi_module" {
  source = "./modules/strapi"
}

#########################################################################
# Application Modules Map
#########################################################################

locals {
  # Aggregate all modules into a single map for easy lookup
  application_modules = {
    odoo      = module.odoo_module.odoo_module
    wordpress = module.wordpress_module.wordpress_module
    moodle    = module.moodle_module.moodle_module
    cyclos    = module.cyclos_module.cyclos_module
    django    = module.django_module.django_module
    openemr   = module.openemr_module.openemr_module
    n8n       = module.n8n_module.n8n_module
    nextcloud = module.nextcloud_module.nextcloud_module
    ghost     = module.ghost_module.ghost_module
    wikijs    = module.wikijs_module.wikijs_module
    plane     = module.plane_module.plane_module
    medusa    = module.medusa_module.medusa_module
    payload   = module.payload_module.payload_module
    invoiceninja = module.invoiceninja_module.invoiceninja_module
    strapi    = module.strapi_module.strapi_module
  }

  #########################################################################
  # Preset Selection Logic
  #########################################################################

  # Determine if using a preset
  using_module = var.application_module != null && var.application_module != ""

  # Get selected preset configuration
  selected_module = local.using_module ? lookup(local.application_modules, var.application_module, null) : null

  # Validation: Ensure preset exists if specified
  module_exists = !local.using_module || local.selected_module != null

  #########################################################################
  # Smart Defaults - Extract preset values with fallback to null
  #########################################################################

  # Container configuration
  module_container_image        = local.using_module && local.selected_module != null ? local.selected_module.container_image : null
  module_container_port         = local.using_module && local.selected_module != null ? local.selected_module.container_port : null
  module_container_image_source = local.using_module && local.selected_module != null ? lookup(local.selected_module, "image_source", null) : null
  module_application_name       = local.using_module && local.selected_module != null ? lookup(local.selected_module, "app_name", null) : null
  module_application_version    = local.using_module && local.selected_module != null ? lookup(local.selected_module, "application_version", lookup(local.selected_module, "app_version", null)) : null
  module_application_description = local.using_module && local.selected_module != null ? lookup(local.selected_module, "description", lookup(local.selected_module, "application_description", null)) : null

  # Container command and args
  module_container_command = local.using_module && local.selected_module != null ? lookup(local.selected_module, "container_command", null) : null
  module_container_args    = local.using_module && local.selected_module != null ? lookup(local.selected_module, "container_args", null) : null

  # Database configuration
  module_database_type             = local.using_module && local.selected_module != null ? local.selected_module.database_type : null
  module_application_database_name = local.using_module && local.selected_module != null ? lookup(local.selected_module, "db_name", null) : null
  module_application_database_user = local.using_module && local.selected_module != null ? lookup(local.selected_module, "db_user", null) : null

  # Cloud SQL volume configuration
  module_enable_cloudsql_volume     = local.using_module && local.selected_module != null ? local.selected_module.enable_cloudsql_volume : null
  module_cloudsql_volume_mount_path = local.using_module && local.selected_module != null ? local.selected_module.cloudsql_volume_mount_path : null

  # NFS configuration
  module_nfs_enabled    = local.using_module && local.selected_module != null ? lookup(local.selected_module, "nfs_enabled", null) : null
  module_nfs_mount_path = local.using_module && local.selected_module != null ? lookup(local.selected_module, "nfs_mount_path", null) : null

  # GCS volumes configuration
  module_gcs_volumes_raw = try(local.selected_module.gcs_volumes, [])

  # Process GCS volumes - replace placeholders and normalize to match var.gcs_volumes
  module_gcs_volumes = [
    for vol in local.module_gcs_volumes_raw : {
      name          = lookup(vol, "name", "gcs-volume-${index(local.module_gcs_volumes_raw, vol)}")
      bucket_name   = lookup(vol, "bucket_name", replace(replace(lookup(vol, "bucket", ""), "$${tenant_id}", var.tenant_deployment_id), "$${deployment_id}", var.deployment_id != null ? var.deployment_id : "default"))
      mount_path    = vol.mount_path
      readonly      = lookup(vol, "read_only", lookup(vol, "readonly", false))
      mount_options = lookup(vol, "mount_options", ["implicit-dirs", "stat-cache-ttl=60s", "type-cache-ttl=60s"])
    }
  ]

  # Resource limits
  module_container_resources = local.using_module && local.selected_module != null ? local.selected_module.container_resources : null
  module_min_instance_count  = local.using_module && local.selected_module != null ? local.selected_module.min_instance_count : null
  module_max_instance_count  = local.using_module && local.selected_module != null ? local.selected_module.max_instance_count : null

  # Probes
  module_startup_probe_config = local.using_module && local.selected_module != null ? lookup(local.selected_module, "startup_probe", null) : null
  module_health_check_config  = local.using_module && local.selected_module != null ? lookup(local.selected_module, "liveness_probe", null) : null

  # Environment variables from preset
  module_environment_variables = local.using_module && local.selected_module != null ? local.selected_module.environment_variables : {}

  # Backup configuration
  module_enable_backup_import = local.using_module && local.selected_module != null ? lookup(local.selected_module, "enable_backup_import", null) : null
  module_backup_source        = local.using_module && local.selected_module != null ? lookup(local.selected_module, "backup_source", null) : null
  module_backup_uri           = local.using_module && local.selected_module != null ? lookup(local.selected_module, "backup_uri", null) : null
  module_backup_format        = local.using_module && local.selected_module != null ? lookup(local.selected_module, "backup_format", null) : null

  # PostgreSQL extensions
  module_enable_postgres_extensions = local.using_module && local.selected_module != null ? lookup(local.selected_module, "enable_postgres_extensions", null) : null
  module_postgres_extensions        = local.using_module && local.selected_module != null ? lookup(local.selected_module, "postgres_extensions", []) : []

  # MySQL plugins
  module_enable_mysql_plugins = local.using_module && local.selected_module != null ? lookup(local.selected_module, "enable_mysql_plugins", null) : null
  module_mysql_plugins        = local.using_module && local.selected_module != null ? lookup(local.selected_module, "mysql_plugins", []) : []

  # Initialization jobs
  module_initialization_jobs_raw = try(local.selected_module.initialization_jobs, [])

  module_initialization_jobs = [
    for job in local.module_initialization_jobs_raw : {
      name              = job.name
      description       = lookup(job, "description", "")
      image             = lookup(job, "image", null)
      command           = lookup(job, "command", [])
      args              = lookup(job, "args", [])
      env_vars          = lookup(job, "env_vars", {})
      secret_env_vars   = lookup(job, "secret_env_vars", {})
      cpu_limit         = lookup(job, "cpu_limit", "1000m")
      memory_limit      = lookup(job, "memory_limit", "512Mi")
      timeout_seconds   = lookup(job, "timeout_seconds", 600)
      max_retries       = lookup(job, "max_retries", 1)
      task_count        = lookup(job, "task_count", 1)
      execution_mode    = lookup(job, "execution_mode", "TASK")
      mount_nfs         = lookup(job, "mount_nfs", false)
      mount_gcs_volumes = lookup(job, "mount_gcs_volumes", [])
      depends_on_jobs   = lookup(job, "depends_on_jobs", [])
      execute_on_apply  = lookup(job, "execute_on_apply", true)
      script_path       = lookup(job, "script_path", null)
    }
  ]

  #########################################################################
  # Final Values - Preset values with manual override capability
  # Manual configuration always takes precedence over preset values
  #########################################################################

  # Container configuration
  final_container_image         = var.container_image != "" && var.container_image != null ? var.container_image : (local.module_container_image != null ? local.module_container_image : "")
  final_container_port          = var.container_port != null ? var.container_port : coalesce(local.module_container_port, 8080)
  final_container_image_source  = var.container_image_source != null ? var.container_image_source : coalesce(local.module_container_image_source, "prebuilt")
  final_application_name        = var.application_name != null ? var.application_name : coalesce(local.module_application_name, "webapp")
  final_application_version     = var.application_version != "latest" ? var.application_version : coalesce(local.module_application_version, "latest")
  final_application_description = var.application_description != "" ? var.application_description : (local.module_application_description != null ? local.module_application_description : "")

  # Database configuration
  final_database_type             = var.database_type != null ? var.database_type : coalesce(local.module_database_type, "POSTGRES")
  final_application_database_name = var.application_database_name != null ? var.application_database_name : coalesce(local.module_application_database_name, "webapp_db")
  final_application_database_user = var.application_database_user != null ? var.application_database_user : coalesce(local.module_application_database_user, "webapp_user")

  # Cloud SQL volume
  final_enable_cloudsql_volume     = var.enable_cloudsql_volume != null ? var.enable_cloudsql_volume : coalesce(local.module_enable_cloudsql_volume, false)
  final_cloudsql_volume_mount_path = var.cloudsql_volume_mount_path != null ? var.cloudsql_volume_mount_path : coalesce(local.module_cloudsql_volume_mount_path, "/cloudsql")

  # NFS configuration
  final_nfs_enabled    = var.nfs_enabled != null ? var.nfs_enabled : coalesce(local.module_nfs_enabled, false)
  final_nfs_mount_path = var.nfs_mount_path != null ? var.nfs_mount_path : coalesce(local.module_nfs_mount_path, "/mnt")

  # GCS volumes - use preset if manual is empty
  final_gcs_volumes_raw = length(var.gcs_volumes) > 0 ? var.gcs_volumes : tolist(local.module_gcs_volumes)
  
  # Normalize GCS volumes structure for main.tf to use
  final_gcs_volumes = [
    for vol in local.final_gcs_volumes_raw : {
      name          = lookup(vol, "name", "gcs-vol-${index(local.final_gcs_volumes_raw, vol)}")
      bucket_name   = lookup(vol, "bucket_name", lookup(vol, "bucket", null)) # Handle both keys
      mount_path    = vol.mount_path
      readonly      = lookup(vol, "read_only", lookup(vol, "readonly", false))
      mount_options = lookup(vol, "mount_options", ["implicit-dirs", "stat-cache-ttl=60s", "type-cache-ttl=60s"])
    }
  ]

  # Resource limits - use preset if manual is default or null
  final_container_resources = (
    var.container_resources != null && (try(var.container_resources.cpu_limit, "") != "" || try(var.container_resources.memory_limit, "") != "")
    ? var.container_resources
    : coalesce(local.module_container_resources, { cpu_limit = "1000m", memory_limit = "512Mi" })
  )
  final_min_instance_count = var.min_instance_count != null ? var.min_instance_count : coalesce(local.module_min_instance_count, 0)
  final_max_instance_count = var.max_instance_count != null ? var.max_instance_count : coalesce(local.module_max_instance_count, 3)

  # Probes
  final_startup_probe_config = var.startup_probe_config != null ? var.startup_probe_config : (local.module_startup_probe_config != null ? local.module_startup_probe_config : {
    enabled               = true
    type                  = "TCP"
    path                  = "/"
    initial_delay_seconds = 0
    timeout_seconds       = 240
    period_seconds        = 240
    failure_threshold     = 1
  })

  final_health_check_config = var.health_check_config != null ? var.health_check_config : (local.module_health_check_config != null ? local.module_health_check_config : {
    enabled               = false
    type                  = "HTTP"
    path                  = "/"
    initial_delay_seconds = 0
    timeout_seconds       = 1
    period_seconds        = 10
    failure_threshold     = 3
  })

  # Environment variables - merge preset and manual (manual takes precedence)
  final_environment_variables = merge(
    local.module_environment_variables,
    var.environment_variables
  )

  # Backup configuration
  final_enable_backup_import = var.enable_backup_import != null ? var.enable_backup_import : coalesce(local.module_enable_backup_import, false)
  final_backup_source        = var.backup_source != null ? var.backup_source : coalesce(local.module_backup_source, "gcs")
  final_backup_uri           = var.backup_uri != null ? var.backup_uri : local.module_backup_uri
  final_backup_format        = var.backup_format != null ? var.backup_format : coalesce(local.module_backup_format, "sql")

  # PostgreSQL extensions
  final_enable_postgres_extensions = var.enable_postgres_extensions != false ? var.enable_postgres_extensions : coalesce(local.module_enable_postgres_extensions, false)
  final_postgres_extensions        = length(var.postgres_extensions) > 0 ? var.postgres_extensions : local.module_postgres_extensions

  # MySQL plugins
  final_enable_mysql_plugins = var.enable_mysql_plugins != false ? var.enable_mysql_plugins : coalesce(local.module_enable_mysql_plugins, false)
  final_mysql_plugins        = length(var.mysql_plugins) > 0 ? var.mysql_plugins : local.module_mysql_plugins

  # Initialization jobs - merge preset and manual
  final_initialization_jobs = concat(
    local.module_initialization_jobs,
    var.initialization_jobs
  )
}
