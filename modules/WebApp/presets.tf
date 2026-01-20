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
# Application Presets - Main Configuration
#
# This file loads individual preset configurations from the presets/
# directory and provides the selection logic for using presets.
#
# Directory Structure:
#   presets/
#   ├── odoo/preset.tf
#   ├── wordpress/preset.tf
#   ├── moodle/preset.tf
#   └── ... (one directory per application)
#
# Each preset defines its own configuration in isolation, making it
# easy to maintain, update, and add new presets without affecting
# existing ones.
#########################################################################

#########################################################################
# Load Individual Preset Configurations
#########################################################################

# Each preset is defined in its own directory under presets/
# This provides clean separation and makes it easy to maintain
module "odoo_preset" {
  source = "./presets/odoo"
}

module "wordpress_preset" {
  source = "./presets/wordpress"
}

module "moodle_preset" {
  source = "./presets/moodle"
}

module "cyclos_preset" {
  source = "./presets/cyclos"
}

module "django_preset" {
  source = "./presets/django"
}

module "openemr_preset" {
  source = "./presets/openemr"
}

module "n8n_preset" {
  source = "./presets/n8n"
}

module "nextcloud_preset" {
  source = "./presets/nextcloud"
}

module "gitlab_preset" {
  source = "./presets/gitlab"
}

#########################################################################
# Application Presets Map
#########################################################################

locals {
  # Aggregate all presets into a single map for easy lookup
  application_presets = {
    odoo      = module.odoo_preset.odoo_preset
    wordpress = module.wordpress_preset.wordpress_preset
    moodle    = module.moodle_preset.moodle_preset
    cyclos    = module.cyclos_preset.cyclos_preset
    django    = module.django_preset.django_preset
    openemr   = module.openemr_preset.openemr_preset
    n8n       = module.n8n_preset.n8n_preset
    nextcloud = module.nextcloud_preset.nextcloud_preset
    gitlab    = module.gitlab_preset.gitlab_preset
  }

  #########################################################################
  # Preset Selection Logic
  #########################################################################

  # Determine if using a preset
  using_preset = var.application_preset != null && var.application_preset != ""

  # Get selected preset configuration
  selected_preset = local.using_preset ? lookup(local.application_presets, var.application_preset, null) : null

  # Validation: Ensure preset exists if specified
  preset_exists = !local.using_preset || local.selected_preset != null

  #########################################################################
  # Smart Defaults - Extract preset values with fallback to null
  #########################################################################

  # Container configuration
  preset_container_image = local.using_preset && local.selected_preset != null ? local.selected_preset.container_image : null
  preset_container_port  = local.using_preset && local.selected_preset != null ? local.selected_preset.container_port : null

  # Database configuration
  preset_database_type = local.using_preset && local.selected_preset != null ? local.selected_preset.database_type : null

  # Cloud SQL volume configuration
  preset_enable_cloudsql_volume     = local.using_preset && local.selected_preset != null ? local.selected_preset.enable_cloudsql_volume : null
  preset_cloudsql_volume_mount_path = local.using_preset && local.selected_preset != null ? local.selected_preset.cloudsql_volume_mount_path : null

  # GCS volumes configuration
  preset_gcs_volumes_raw = local.using_preset && local.selected_preset != null ? local.selected_preset.gcs_volumes : []

  # Process GCS volumes - replace placeholders
  preset_gcs_volumes = [
    for vol in local.preset_gcs_volumes_raw : {
      bucket     = replace(replace(vol.bucket, "$${tenant_id}", var.tenant_deployment_id), "$${deployment_id}", var.deployment_id != null ? var.deployment_id : "default")
      mount_path = vol.mount_path
      read_only  = vol.read_only
    }
  ]

  # Resource limits
  preset_container_resources = local.using_preset && local.selected_preset != null ? local.selected_preset.container_resources : null
  preset_min_instance_count  = local.using_preset && local.selected_preset != null ? local.selected_preset.min_instance_count : null
  preset_max_instance_count  = local.using_preset && local.selected_preset != null ? local.selected_preset.max_instance_count : null

  # Environment variables from preset
  preset_environment_variables = local.using_preset && local.selected_preset != null ? local.selected_preset.environment_variables : {}

  # PostgreSQL extensions
  preset_enable_postgres_extensions = local.using_preset && local.selected_preset != null ? lookup(local.selected_preset, "enable_postgres_extensions", null) : null
  preset_postgres_extensions        = local.using_preset && local.selected_preset != null ? lookup(local.selected_preset, "postgres_extensions", []) : []

  # MySQL plugins
  preset_enable_mysql_plugins = local.using_preset && local.selected_preset != null ? lookup(local.selected_preset, "enable_mysql_plugins", null) : null
  preset_mysql_plugins        = local.using_preset && local.selected_preset != null ? lookup(local.selected_preset, "mysql_plugins", []) : []

  #########################################################################
  # Final Values - Preset values with manual override capability
  # Manual configuration always takes precedence over preset values
  #########################################################################

  # Container configuration
  final_container_image = var.container_image != "" && var.container_image != null ? var.container_image : coalesce(local.preset_container_image, "")
  final_container_port  = var.container_port != 8080 ? var.container_port : coalesce(local.preset_container_port, 8080)

  # Database configuration
  final_database_type = var.database_type != "POSTGRES" ? var.database_type : coalesce(local.preset_database_type, "POSTGRES")

  # Cloud SQL volume
  final_enable_cloudsql_volume     = var.enable_cloudsql_volume != false ? var.enable_cloudsql_volume : coalesce(local.preset_enable_cloudsql_volume, false)
  final_cloudsql_volume_mount_path = var.cloudsql_volume_mount_path != "/cloudsql" ? var.cloudsql_volume_mount_path : coalesce(local.preset_cloudsql_volume_mount_path, "/cloudsql")

  # GCS volumes - use preset if manual is empty
  final_gcs_volumes = length(var.gcs_volumes) > 0 ? var.gcs_volumes : local.preset_gcs_volumes

  # Resource limits - use preset if manual is default
  final_container_resources = (
    var.container_resources.cpu_limit != "1000m" || var.container_resources.memory_limit != "512Mi"
    ? var.container_resources
    : coalesce(local.preset_container_resources, var.container_resources)
  )
  final_min_instance_count = var.min_instance_count != 0 ? var.min_instance_count : coalesce(local.preset_min_instance_count, 0)
  final_max_instance_count = var.max_instance_count != 3 ? var.max_instance_count : coalesce(local.preset_max_instance_count, 3)

  # Environment variables - merge preset and manual (manual takes precedence)
  final_environment_variables = merge(
    local.preset_environment_variables,
    var.environment_variables
  )

  # PostgreSQL extensions
  final_enable_postgres_extensions = var.enable_postgres_extensions != false ? var.enable_postgres_extensions : coalesce(local.preset_enable_postgres_extensions, false)
  final_postgres_extensions        = length(var.postgres_extensions) > 0 ? var.postgres_extensions : local.preset_postgres_extensions

  # MySQL plugins
  final_enable_mysql_plugins = var.enable_mysql_plugins != false ? var.enable_mysql_plugins : coalesce(local.preset_enable_mysql_plugins, false)
  final_mysql_plugins        = length(var.mysql_plugins) > 0 ? var.mysql_plugins : local.preset_mysql_plugins
}
