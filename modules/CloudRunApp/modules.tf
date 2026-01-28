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
#########################################################################

locals {
  #########################################################################
  # Preset Selection Logic (Hardcoded for Cyclos)
  #########################################################################

  # Automatically select the first available module preset
  using_module    = length(keys(local.application_modules)) > 0
  selected_module = local.using_module ? values(local.application_modules)[0] : null
  module_exists   = local.using_module

  #########################################################################
  # Smart Defaults - Extract preset values
  #########################################################################

  # Container configuration
  module_container_image        = local.selected_module.container_image
  module_container_port         = local.selected_module.container_port
  module_container_image_source = try(local.selected_module.image_source, "prebuilt")
  module_application_name       = try(local.selected_module.app_name, "cyclos")
  module_application_version    = try(local.selected_module.application_version, try(local.selected_module.app_version, null))
  module_application_description = try(local.selected_module.description, try(local.selected_module.application_description, ""))
  module_application_display_name = try(local.selected_module.display_name, "Cyclos Community Edition")

  # Container command and args
  module_container_command = try(local.selected_module.container_command, null)
  module_container_args    = try(local.selected_module.container_args, null)

  # Container build configuration
  module_container_build_config = try(local.selected_module.container_build_config, null)

  # Image Mirroring configuration
  module_enable_image_mirroring = try(local.selected_module.enable_image_mirroring, false)

  # Database configuration
  module_database_type             = local.selected_module.database_type
  module_application_database_name = try(local.selected_module.db_name, "cyclos")
  module_application_database_user = try(local.selected_module.db_user, "cyclos")

  # Cloud SQL volume configuration
  module_enable_cloudsql_volume     = try(local.selected_module.enable_cloudsql_volume, false)
  module_cloudsql_volume_mount_path = try(local.selected_module.cloudsql_volume_mount_path, "/cloudsql")

  # NFS configuration
  module_nfs_enabled    = try(local.selected_module.nfs_enabled, false)
  module_nfs_mount_path = try(local.selected_module.nfs_mount_path, "/mnt")

  # GCS volumes configuration
  module_gcs_volumes_raw = try(local.selected_module.gcs_volumes, [])

  # Process GCS volumes
  module_gcs_volumes = [
    for vol in local.module_gcs_volumes_raw : {
      name          = try(vol.name, "gcs-volume-${index(local.module_gcs_volumes_raw, vol)}")
      bucket_name   = try(vol.bucket_name, replace(replace(try(vol.bucket, ""), "$${tenant_id}", var.tenant_deployment_id), "$${deployment_id}", var.deployment_id != null ? var.deployment_id : "default"))
      mount_path    = vol.mount_path
      readonly      = try(vol.read_only, try(vol.readonly, false))
      mount_options = try(vol.mount_options, ["implicit-dirs", "metadata-cache-ttl-secs=60"])
    }
  ]

  # Resource limits
  module_container_resources = local.selected_module.container_resources
  module_min_instance_count  = local.selected_module.min_instance_count
  module_max_instance_count  = local.selected_module.max_instance_count

  # Probes
  module_startup_probe_config = try(local.selected_module.startup_probe, null)
  module_health_check_config  = try(local.selected_module.liveness_probe, null)

  # Environment variables from preset
  module_environment_variables = local.selected_module.environment_variables

  # Backup configuration
  module_enable_backup_import = try(local.selected_module.enable_backup_import, false)
  module_backup_source        = try(local.selected_module.backup_source, "gcs")
  module_backup_uri           = try(local.selected_module.backup_uri, null)
  module_backup_format        = try(local.selected_module.backup_format, "sql")

  # PostgreSQL extensions
  module_enable_postgres_extensions = try(local.selected_module.enable_postgres_extensions, false)
  module_postgres_extensions        = try(local.selected_module.postgres_extensions, [])

  # MySQL plugins
  module_enable_mysql_plugins = try(local.selected_module.enable_mysql_plugins, false)
  module_mysql_plugins        = try(local.selected_module.mysql_plugins, [])

  # Initialization jobs
  module_initialization_jobs_raw = try(local.selected_module.initialization_jobs, [])

  module_initialization_jobs = [
    for job in local.module_initialization_jobs_raw : {
      name              = job.name
      description       = try(job.description, "")
      image             = try(job.image, null)
      command           = try(job.command, [])
      args              = try(job.args, [])
      env_vars          = try(job.env_vars, {})
      secret_env_vars   = try(job.secret_env_vars, {})
      cpu_limit         = try(job.cpu_limit, "1000m")
      memory_limit      = try(job.memory_limit, "512Mi")
      timeout_seconds   = try(job.timeout_seconds, 600)
      max_retries       = try(job.max_retries, 1)
      task_count        = try(job.task_count, 1)
      execution_mode    = try(job.execution_mode, "TASK")
      mount_nfs         = try(job.mount_nfs, false)
      mount_gcs_volumes = try(job.mount_gcs_volumes, [])
      depends_on_jobs   = try(job.depends_on_jobs, [])
      execute_on_apply  = try(job.execute_on_apply, true)
      script_path       = try(job.script_path, null)
    }
  ]

  #########################################################################
  # Final Values
  #########################################################################

  # Container configuration
  _container_image_raw          = local.module_container_image
  final_container_image         = "${local._container_image_raw}:${local.final_application_version}"
  final_container_port          = local.module_container_port
  final_container_image_source  = local.module_container_image_source
  final_application_name        = local.module_application_name
  final_application_version     = var.application_version # Retained
  final_application_description = local.module_application_description
  final_application_display_name = local.module_application_display_name

  # Database configuration
  final_database_type             = local.module_database_type
  final_application_database_name = local.module_application_database_name
  final_application_database_user = local.module_application_database_user

  # Cloud SQL volume
  final_enable_cloudsql_volume     = local.module_enable_cloudsql_volume
  final_cloudsql_volume_mount_path = local.module_cloudsql_volume_mount_path

  # NFS configuration (Retained vars)
  final_nfs_enabled    = var.nfs_enabled != null ? var.nfs_enabled : local.module_nfs_enabled
  final_nfs_mount_path = var.nfs_mount_path != null ? var.nfs_mount_path : local.module_nfs_mount_path

  # GCS volumes (Retained vars)
  final_gcs_volumes_raw = length(var.gcs_volumes) > 0 ? var.gcs_volumes : tolist(local.module_gcs_volumes)
  
  final_gcs_volumes = [
    for vol in local.final_gcs_volumes_raw : {
      name          = try(vol.name, "gcs-vol-${index(local.final_gcs_volumes_raw, vol)}")
      bucket_name   = try(vol.bucket_name, try(vol.bucket, null))
      mount_path    = vol.mount_path
      readonly      = try(vol.read_only, try(vol.readonly, false))
      mount_options = try(vol.mount_options, ["implicit-dirs", "metadata-cache-ttl-secs=60"])
    }
  ]

  # Resource limits
  final_container_resources = local.module_container_resources
  final_min_instance_count = local.module_min_instance_count
  final_max_instance_count = local.module_max_instance_count

  # Probes
  final_startup_probe_config = local.module_startup_probe_config
  final_health_check_config  = local.module_health_check_config

  # Environment variables (Retained vars)
  final_environment_variables = merge(
    local.module_environment_variables,
    var.environment_variables
  )

  # Backup configuration (Retained vars)
  final_enable_backup_import = var.enable_backup_import != null ? var.enable_backup_import : local.module_enable_backup_import
  final_backup_source        = var.backup_source != null ? var.backup_source : local.module_backup_source
  final_backup_uri           = var.backup_uri != null ? var.backup_uri : local.module_backup_uri
  final_backup_format        = var.backup_format != null ? var.backup_format : local.module_backup_format

  # PostgreSQL extensions
  final_enable_postgres_extensions = local.module_enable_postgres_extensions
  final_postgres_extensions        = local.module_postgres_extensions

  # MySQL plugins
  final_enable_mysql_plugins = local.module_enable_mysql_plugins
  final_mysql_plugins        = local.module_mysql_plugins

  # Initialization jobs (Retained vars)
  final_initialization_jobs = concat(
    local.module_initialization_jobs,
    var.initialization_jobs
  )

  # Final Image Mirroring
  final_enable_image_mirroring = local.module_enable_image_mirroring
}
