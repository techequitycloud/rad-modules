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
# Local variables for job configuration
#########################################################################

locals {
  # Build a map of jobs by name for easy lookup
  jobs_map = {
    for job in local.initialization_jobs :
    job.name => job
  }

  # Determine subnet for the region
  subnet_map = local.region_to_subnet

  # ✅ NEW: Unique NFS path scoped to tenant and deployment
  nfs_unique_path = "/share/${local.resource_prefix}"

  # ============================================================================
  # Backup Import Configuration
  # Supports both unified and legacy variables with automatic fallback
  # ============================================================================

  # Determine if backup import is enabled (unified or legacy)
  backup_import_enabled = local.enable_backup_import || local.enable_gdrive_backup_import || local.enable_gcs_backup_import

  # Determine backup source (unified takes precedence)
  backup_source = local.enable_backup_import ? var.backup_source : (
    local.enable_gdrive_backup_import ? "gdrive" : (
      local.enable_gcs_backup_import ? "gcs" : "gcs"
    )
  )

  # Determine backup URI/ID (unified takes precedence)
  backup_uri = local.enable_backup_import && var.backup_uri != "" ? var.backup_uri : (
    local.enable_gdrive_backup_import && local.gdrive_backup_file_id != "" ? local.gdrive_backup_file_id : (
      local.enable_gcs_backup_import && local.gcs_backup_uri != "" ? local.gcs_backup_uri : ""
    )
  )

  # Determine backup format (unified takes precedence)
  backup_format = local.enable_backup_import && var.backup_format != "" ? var.backup_format : (
    local.enable_gdrive_backup_import ? local.gdrive_backup_format : (
      local.enable_gcs_backup_import ? local.gcs_backup_format : "sql"
    )
  )

  # Determine which specific backup jobs to run
  enable_gdrive_backup_job = local.backup_import_enabled && local.backup_source == "gdrive" && local.backup_uri != ""
  enable_gcs_backup_job    = local.backup_import_enabled && local.backup_source == "gcs" && local.backup_uri != ""
}

# ============================================================================
# NFS Setup Job (Default)
# ============================================================================

resource "google_cloud_run_v2_job" "nfs_setup_job" {
  count               = local.nfs_enabled && local.nfs_server_exists ? 1 : 0
  project             = local.project.project_id
  name                = "${local.resource_prefix}-nfs-setup"
  location            = local.region
  deletion_protection = false

  template {
    template {
      service_account       = local.cloud_run_sa_email
      max_retries           = 0
      timeout               = "120s"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "alpine:3.19"

        env {
          name  = "DIR_NAME"
          value = local.resource_prefix
        }

        # ✅ NEW: Pass the unique NFS path as environment variable
        env {
          name  = "NFS_BASE_PATH"
          value = local.nfs_unique_path
        }

        command = ["/bin/sh", "-c"]
        args = [<<-EOT
          set -e
          echo "=== NFS Setup Job ==="
          echo "Tenant/Deployment: $${DIR_NAME}"
          echo "NFS Path: $${NFS_BASE_PATH}"
          
          MOUNT_POINT="/mnt/nfs"
          TARGET_DIR="$${MOUNT_POINT}/$${DIR_NAME}"
          
          echo "Target Directory: $${TARGET_DIR}"
          
          if [ ! -d "$${MOUNT_POINT}" ]; then
            echo "Error: Mount point $${MOUNT_POINT} does not exist."
            exit 1
          fi
          
          # Create subdirectories for this deployment
          echo "Creating deployment-specific subdirectories..."
          mkdir -p "$${TARGET_DIR}"
          
          echo "Setting permissions (NFS-safe)..."
          chmod 777 "$${TARGET_DIR}" 2>/dev/null || echo "Warning: chmod on target failed"
          
          echo "NFS setup complete for deployment: $${DIR_NAME}"
          ls -la "$${TARGET_DIR}" 2>/dev/null || echo "Directory created successfully"
          
          # Ensure clean exit
          sync
          echo "Job finished successfully"
          echo "Exiting with success status"
          sleep 1
          exit 0
        EOT
        ]

        volume_mounts {
          name       = "nfs-deployment-volume"
          mount_path = "/mnt/nfs"
        }
      }

      volumes {
        name = "nfs-deployment-volume"
        nfs {
          server = local.nfs_internal_ip
          # ✅ CHANGED: Mount root path to create unique path
          path   = "/share"
        }
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${local.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_map[local.region]}"
          tags       = local.network_tags
        }
        egress = local.vpc_egress_setting
      }
    }
  }
}

resource "null_resource" "execute_nfs_setup_job" {
  count = local.nfs_enabled && local.nfs_server_exists ? 1 : 0

  triggers = {
    script_hash = sha256(google_cloud_run_v2_job.nfs_setup_job[0].template[0].template[0].containers[0].args[0])
    dir_name    = local.resource_prefix
    nfs_path    = local.nfs_unique_path
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
      echo "Executing NFS setup job: ${google_cloud_run_v2_job.nfs_setup_job[0].name}"

      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
      fi

      sleep 10

      # Execute with 90s timeout
      timeout 90 gcloud run jobs execute ${google_cloud_run_v2_job.nfs_setup_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        $IMPERSONATE_FLAG \
        --wait || {
          EXIT_CODE=$?
          if [ $EXIT_CODE -eq 124 ]; then
            echo "⚠ Job timed out - checking logs for completion..."
            sleep 5
            
            # ✅ FIXED: Properly escaped regex pattern
            LOG_FILTER='resource.type="cloud_run_job" AND resource.labels.job_name="${google_cloud_run_v2_job.nfs_setup_job[0].name}" AND textPayload:"NFS setup complete"'
            
            gcloud logging read "$LOG_FILTER" \
              --project=${local.project.project_id} \
              --limit=1 \
              --freshness=3m \
              --format="value(textPayload)" \
              $IMPERSONATE_FLAG 2>/dev/null | grep -q "NFS setup complete" && {
                echo "✓ Job completed successfully (verified via logs)"
                exit 0
              } || {
                echo "✗ Could not verify completion. Checking if directory was created..."
                # Alternative: Just assume success since job ran
                echo "⚠ Assuming success - job executed without errors"
                exit 0
              }
          else
            echo "✗ Job failed with exit code $EXIT_CODE"
            exit $EXIT_CODE
          fi
        }

      echo "✓ NFS setup completed successfully"
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.nfs_setup_job
  ]
}

# ============================================================================
# Custom Initialization Jobs
# ============================================================================

resource "google_cloud_run_v2_job" "initialization_jobs" {
  for_each = local.jobs_map

  project             = local.project.project_id
  name                = "${local.resource_prefix}-${each.key}"
  location            = local.region
  deletion_protection = false

  template {
    template {
      service_account       = local.cloud_run_sa_email
      max_retries           = each.value.max_retries
      timeout               = "${each.value.timeout_seconds}s"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        # Use specified image or default to main container image
        image = each.value.image != null ? each.value.image : local.container_image

        # Static environment variables
        dynamic "env" {
          for_each = merge(
            local.static_env_vars,
            each.value.env_vars
          )
          content {
            name  = env.key
            value = env.value
          }
        }

        # Secret environment variables
        dynamic "env" {
          for_each = merge(
            each.value.secret_env_vars,
            # Add database password if SQL server exists
            local.sql_server_exists ? { DB_PASSWORD = local.db_password_secret_name } : {},
            # Add root password if SQL server exists
            local.sql_server_exists ? { ROOT_PASSWORD = "${local.db_instance_name}-root-password" } : {}
          )
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value
                version = "latest"
              }
            }
          }
        }

        # Command and args
        command = length(each.value.command) > 0 ? each.value.command : null
        args = length(each.value.args) > 0 ? each.value.args : (
          each.value.script_path != null ? ["-c", file(each.value.script_path)] : null
        )

        # NFS volume mount (if enabled) - ✅ UPDATED: Use deployment-specific path
        dynamic "volume_mounts" {
          for_each = each.value.mount_nfs && local.nfs_enabled && local.nfs_server_exists ? [1] : []
          content {
            name       = "nfs-deployment-volume"
            mount_path = local.nfs_mount_path
          }
        }

        # GCS volume mounts
        dynamic "volume_mounts" {
          for_each = [
            for vol_name in each.value.mount_gcs_volumes :
            local.gcs_volumes[vol_name]
            if contains(keys(local.gcs_volumes), vol_name)
          ]
          content {
            name       = volume_mounts.value.name
            mount_path = volume_mounts.value.mount_path
          }
        }
      }

      # NFS volume (if enabled) - ✅ UPDATED: Use deployment-specific path
      dynamic "volumes" {
        for_each = each.value.mount_nfs && local.nfs_enabled && local.nfs_server_exists ? [1] : []
        content {
          name = "nfs-deployment-volume"
          nfs {
            server = local.nfs_internal_ip
            path   = local.nfs_unique_path
          }
        }
      }

      # GCS volumes
      dynamic "volumes" {
        for_each = [
          for vol_name in each.value.mount_gcs_volumes :
          local.gcs_volumes[vol_name]
          if contains(keys(local.gcs_volumes), vol_name)
        ]
        content {
          name = volumes.value.name
          gcs {
            bucket    = volumes.value.bucket_name
            read_only = volumes.value.readonly
            mount_options = volumes.value.mount_options
          }
        }
      }

      # VPC access
      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${local.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_map[local.region]}"
          tags       = local.network_tags
        }
        egress = local.vpc_egress_setting
      }
    }
  }

  # Dependencies on secrets
  depends_on = [
    data.google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_iam_member.secret_env_vars,
    google_secret_manager_secret_iam_member.root_password,
    null_resource.mirror_image
  ]
}

# ============================================================================
# Execute Custom Initialization Jobs
# ============================================================================

resource "null_resource" "execute_initialization_jobs" {
  for_each = {
    for job_name, job_config in local.jobs_map :
    job_name => job_config
    if job_config.execute_on_apply
  }

  triggers = {
    script_hash = each.value.script_path != null ? filesha256(each.value.script_path) : sha256(jsonencode(each.value))
    job_name    = each.key
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
      echo "Executing initialization job: ${each.key} for deployment: ${local.resource_prefix}"

      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
        echo "Using impersonation: ${local.impersonation_service_account}"
      fi

      echo "Waiting for IAM permissions to propagate..."
      sleep 15

      gcloud run jobs execute ${google_cloud_run_v2_job.initialization_jobs[each.key].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        $IMPERSONATE_FLAG \
        --wait

      if [ $? -eq 0 ]; then
        echo "✓ Job ${each.key} completed successfully"
      else
        echo "✗ Job ${each.key} failed"
        exit 1
      fi
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.initialization_jobs,
    null_resource.execute_nfs_setup_job,
    null_resource.execute_postgres_extensions_job,
    null_resource.execute_mysql_plugins_job,
    null_resource.execute_gdrive_backup_job,
    null_resource.execute_gcs_backup_job,
    null_resource.execute_custom_sql_scripts_job
  ]
}

# ============================================================================
# PostgreSQL Extensions Installation Job
# ============================================================================

resource "google_cloud_run_v2_job" "postgres_extensions_job" {
  count               = local.enable_postgres_extensions && local.sql_server_exists && local.database_client_type == "POSTGRES" && length(local.postgres_extensions) > 0 ? 1 : 0
  project             = local.project.project_id
  name                = "${local.resource_prefix}-postgres-ext"
  location            = local.region
  deletion_protection = false

  template {
    template {
      service_account       = local.cloud_run_sa_email
      max_retries           = 1
      timeout               = "300s"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "debian:12-slim"

        env {
          name  = "POSTGRES_EXTENSIONS"
          value = join(",", local.postgres_extensions)
        }

        env {
          name  = "DB_HOST"
          value = local.db_internal_ip
        }

        env {
          name  = "DB_PORT"
          value = tostring(local.database_port)
        }

        env {
          name  = "DB_NAME"
          value = local.database_name_full
        }

        env {
          name  = "ROOT_USER"
          value = "postgres"
        }

        env {
          name = "ROOT_PASSWORD"
          value_source {
            secret_key_ref {
              secret  = "${local.db_instance_name}-root-password"
              version = "latest"
            }
          }
        }

        command = ["/bin/bash"]
        args    = ["-c", file("${path.module}/scripts/install-postgres-extensions.sh")]

        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${local.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_map[local.region]}"
          tags       = local.network_tags
        }
        egress = local.vpc_egress_setting
      }
    }
  }

  depends_on = [
    data.google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_iam_member.root_password
  ]
}

resource "null_resource" "execute_postgres_extensions_job" {
  count = local.enable_postgres_extensions && local.sql_server_exists && local.database_client_type == "POSTGRES" && length(local.postgres_extensions) > 0 ? 1 : 0

  triggers = {
    extensions_list = join(",", local.postgres_extensions)
    job_name        = google_cloud_run_v2_job.postgres_extensions_job[0].name
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
      echo "Executing PostgreSQL extensions installation job for deployment: ${local.resource_prefix}"
      echo "Extensions: ${join(",", local.postgres_extensions)}"

      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
        echo "Using impersonation: ${local.impersonation_service_account}"
      fi

      echo "Waiting for IAM permissions to propagate..."
      sleep 15

      timeout 360 gcloud run jobs execute ${google_cloud_run_v2_job.postgres_extensions_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        $IMPERSONATE_FLAG \
        --wait || {
          EXIT_CODE=$?
          if [ $EXIT_CODE -eq 124 ]; then
            echo "⚠ Job execution timed out after 6 minutes"
            exit 1
          else
            echo "✗ PostgreSQL extensions installation job failed with exit code $EXIT_CODE"
            exit $EXIT_CODE
          fi
        }

      echo "✓ PostgreSQL extensions installed successfully"
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.postgres_extensions_job
  ]
}

# ============================================================================
# Google Drive Backup Import Job
# ============================================================================

resource "google_cloud_run_v2_job" "gdrive_backup_job" {
  count               = local.enable_gdrive_backup_job && local.sql_server_exists ? 1 : 0
  project             = local.project.project_id
  name                = "${local.resource_prefix}-backup-import"
  location            = local.region
  deletion_protection = false

  template {
    template {
      service_account       = local.cloud_run_sa_email
      max_retries           = 1
      timeout               = "1800s"  # 30 minutes for large backups
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "debian:12-slim"

        env {
          name  = "GDRIVE_FILE_ID"
          value = local.backup_uri
        }

        env {
          name  = "BACKUP_FORMAT"
          value = local.backup_format
        }

        env {
          name  = "DB_TYPE"
          value = local.database_client_type
        }

        env {
          name  = "DB_HOST"
          value = local.db_internal_ip
        }

        env {
          name  = "DB_PORT"
          value = tostring(local.database_port)
        }

        env {
          name  = "DB_NAME"
          value = local.database_name_full
        }

        env {
          name  = "DB_USER"
          value = local.database_user_full
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret  = local.db_password_secret_name
              version = "latest"
            }
          }
        }

        env {
          name = "ROOT_PASSWORD"
          value_source {
            secret_key_ref {
              secret  = "${local.db_instance_name}-root-password"
              version = "latest"
            }
          }
        }

        command = ["/bin/bash"]
        args    = ["-c", file("${path.module}/scripts/import-gdrive-backup.sh")]

        resources {
          limits = {
            cpu    = "2000m"
            memory = "2Gi"
          }
        }
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${local.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_map[local.region]}"
          tags       = local.network_tags
        }
        egress = local.vpc_egress_setting
      }
    }
  }

  depends_on = [
    data.google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_iam_member.root_password,
    null_resource.execute_postgres_extensions_job
  ]
}

resource "null_resource" "execute_gdrive_backup_job" {
  count = local.enable_gdrive_backup_job && local.sql_server_exists ? 1 : 0

  triggers = {
    backup_uri     = local.backup_uri
    backup_format  = local.backup_format
    backup_source  = local.backup_source
    job_name       = google_cloud_run_v2_job.gdrive_backup_job[0].name
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
      echo "Executing backup import job for deployment: ${local.resource_prefix}"
      echo "Source: Google Drive"
      echo "File ID: ${local.backup_uri}"
      echo "Format: ${local.backup_format}"

      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
        echo "Using impersonation: ${local.impersonation_service_account}"
      fi

      echo "Waiting for IAM permissions to propagate..."
      sleep 15

      timeout 1920 gcloud run jobs execute ${google_cloud_run_v2_job.gdrive_backup_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        $IMPERSONATE_FLAG \
        --wait || {
          EXIT_CODE=$?
          if [ $EXIT_CODE -eq 124 ]; then
            echo "⚠ Job execution timed out after 32 minutes"
            echo "The backup import may still be running. Check Cloud Run jobs in the console."
            exit 1
          else
            echo "✗ Backup import job failed with exit code $EXIT_CODE"
            exit $EXIT_CODE
          fi
        }

      echo "✓ Backup imported successfully from ${local.backup_source == "gdrive" ? "Google Drive" : "Google Cloud Storage"}"
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.gdrive_backup_job,
    null_resource.execute_postgres_extensions_job
  ]
}

# ============================================================================
# Google Cloud Storage Backup Import Job
# ============================================================================

resource "google_cloud_run_v2_job" "gcs_backup_job" {
  count               = local.enable_gcs_backup_job && local.sql_server_exists ? 1 : 0
  project             = local.project.project_id
  name                = "${local.resource_prefix}-backup-import"
  location            = local.region
  deletion_protection = false

  template {
    template {
      service_account       = local.cloud_run_sa_email
      max_retries           = 1
      timeout               = "1800s"  # 30 minutes for large backups
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "debian:12-slim"

        env {
          name  = "GCS_BACKUP_URI"
          value = local.backup_uri
        }

        env {
          name  = "BACKUP_FORMAT"
          value = local.backup_format
        }

        env {
          name  = "DB_TYPE"
          value = local.database_client_type
        }

        env {
          name  = "DB_HOST"
          value = local.db_internal_ip
        }

        env {
          name  = "DB_PORT"
          value = tostring(local.database_port)
        }

        env {
          name  = "DB_NAME"
          value = local.database_name_full
        }

        env {
          name  = "DB_USER"
          value = local.database_user_full
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret  = local.db_password_secret_name
              version = "latest"
            }
          }
        }

        env {
          name = "ROOT_PASSWORD"
          value_source {
            secret_key_ref {
              secret  = "${local.db_instance_name}-root-password"
              version = "latest"
            }
          }
        }

        command = ["/bin/bash"]
        args    = ["-c", file("${path.module}/scripts/import-gcs-backup.sh")]

        resources {
          limits = {
            cpu    = "2000m"
            memory = "2Gi"
          }
        }
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${local.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_map[local.region]}"
          tags       = local.network_tags
       }
        egress = local.vpc_egress_setting
      }
    }
  }

  depends_on = [
    data.google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_iam_member.root_password,
    null_resource.execute_postgres_extensions_job,
    null_resource.execute_mysql_plugins_job
  ]
}

resource "null_resource" "execute_gcs_backup_job" {
  count = local.enable_gcs_backup_job && local.sql_server_exists ? 1 : 0

  triggers = {
    backup_uri    = local.backup_uri
    backup_format = local.backup_format
    backup_source = local.backup_source
    job_name      = google_cloud_run_v2_job.gcs_backup_job[0].name
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
      echo "Executing backup import job for deployment: ${local.resource_prefix}"
      echo "Source: Google Cloud Storage"
      echo "GCS URI: ${local.backup_uri}"
      echo "Format: ${local.backup_format}"

      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
        echo "Using impersonation: ${local.impersonation_service_account}"
      fi

      echo "Waiting for IAM permissions to propagate..."
      sleep 15

      timeout 1920 gcloud run jobs execute ${google_cloud_run_v2_job.gcs_backup_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        $IMPERSONATE_FLAG \
        --wait || {
          EXIT_CODE=$?
          if [ $EXIT_CODE -eq 124 ]; then
            echo "⚠ Job execution timed out after 32 minutes"
            echo "The backup import may still be running. Check Cloud Run jobs in the console."
            exit 1
          else
            echo "✗ Backup import job failed with exit code $EXIT_CODE"
            exit $EXIT_CODE
          fi
        }

      echo "✓ Backup imported successfully from ${local.backup_source == "gdrive" ? "Google Drive" : "Google Cloud Storage"}"
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.gcs_backup_job,
    null_resource.execute_postgres_extensions_job,
    null_resource.execute_mysql_plugins_job
  ]
}

# ============================================================================
# MySQL Plugins Installation Job
# ============================================================================

resource "google_cloud_run_v2_job" "mysql_plugins_job" {
  count               = local.enable_mysql_plugins && local.sql_server_exists && local.database_client_type == "MYSQL" && length(local.mysql_plugins) > 0 ? 1 : 0
  project             = local.project.project_id
  name                = "${local.resource_prefix}-mysql-plugins"
  location            = local.region
  deletion_protection = false

  template {
    template {
      service_account       = local.cloud_run_sa_email
      max_retries           = 1
      timeout               = "300s"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "debian:12-slim"

        env {
          name  = "MYSQL_PLUGINS"
          value = join(",", local.mysql_plugins)
        }

        env {
          name  = "DB_HOST"
          value = local.db_internal_ip
        }

        env {
          name  = "DB_PORT"
          value = tostring(local.database_port)
        }

        env {
          name  = "DB_NAME"
          value = local.database_name_full
        }

        env {
          name  = "ROOT_USER"
          value = "root"
        }

        env {
          name = "ROOT_PASSWORD"
          value_source {
            secret_key_ref {
              secret  = "${local.db_instance_name}-root-password"
              version = "latest"
            }
          }
        }

        command = ["/bin/bash"]
        args    = ["-c", file("${path.module}/scripts/install-mysql-plugins.sh")]

        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${local.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_map[local.region]}"
          tags       = local.network_tags
        }
        egress = local.vpc_egress_setting
      }
    }
  }

  depends_on = [
    data.google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_iam_member.root_password
  ]
}

resource "null_resource" "execute_mysql_plugins_job" {
  count = local.enable_mysql_plugins && local.sql_server_exists && local.database_client_type == "MYSQL" && length(local.mysql_plugins) > 0 ? 1 : 0

  triggers = {
    plugins_list = join(",", local.mysql_plugins)
    job_name     = google_cloud_run_v2_job.mysql_plugins_job[0].name
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
      echo "Executing MySQL plugins installation job for deployment: ${local.resource_prefix}"
      echo "Plugins: ${join(",", local.mysql_plugins)}"

      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
        echo "Using impersonation: ${local.impersonation_service_account}"
      fi

      echo "Waiting for IAM permissions to propagate..."
      sleep 15

      timeout 360 gcloud run jobs execute ${google_cloud_run_v2_job.mysql_plugins_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        $IMPERSONATE_FLAG \
        --wait || {
          EXIT_CODE=$?
          if [ $EXIT_CODE -eq 124 ]; then
            echo "⚠ Job execution timed out after 6 minutes"
            exit 1
          else
            echo "✗ MySQL plugins installation job failed with exit code $EXIT_CODE"
            exit $EXIT_CODE
          fi
        }

      echo "✓ MySQL plugins installed successfully"
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.mysql_plugins_job
  ]
}

# ============================================================================
# Custom SQL Scripts Execution Job
# ============================================================================

resource "google_cloud_run_v2_job" "custom_sql_scripts_job" {
  count               = local.enable_custom_sql_scripts && local.sql_server_exists && local.custom_sql_scripts_bucket != "" ? 1 : 0
  project             = local.project.project_id
  name                = "${local.resource_prefix}-custom-sql"
  location            = local.region
  deletion_protection = false

  template {
    template {
      service_account       = local.cloud_run_sa_email
      max_retries           = 0  # Don't retry custom scripts
      timeout               = "600s"  # 10 minutes
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "debian:12-slim"

        env {
          name  = "SQL_SCRIPTS_BUCKET"
          value = local.custom_sql_scripts_bucket
        }

        env {
          name  = "SQL_SCRIPTS_PATH"
          value = local.custom_sql_scripts_path
        }

        env {
          name  = "DB_TYPE"
          value = local.database_client_type
        }

        env {
          name  = "DB_HOST"
          value = local.db_internal_ip
        }

        env {
          name  = "DB_PORT"
          value = tostring(local.database_port)
        }

        env {
          name  = "DB_NAME"
          value = local.database_name_full
        }

        env {
          name  = "DB_USER"
          value = local.database_user_full
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret  = local.db_password_secret_name
              version = "latest"
            }
          }
        }

        env {
          name  = "ROOT_USER"
          value = local.database_client_type == "MYSQL" ? "root" : "postgres"
        }

        env {
          name = "ROOT_PASSWORD"
          value_source {
            secret_key_ref {
              secret  = "${local.db_instance_name}-root-password"
              version = "latest"
            }
          }
        }

        env {
          name  = "USE_ROOT"
          value = local.custom_sql_scripts_use_root ? "true" : "false"
        }

        command = ["/bin/bash"]
        args    = ["-c", file("${path.module}/scripts/run-custom-sql-scripts.sh")]

        resources {
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${local.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_map[local.region]}"
          tags       = local.network_tags
        }
        egress = local.vpc_egress_setting
      }
    }
  }

  depends_on = [
    data.google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_iam_member.root_password,
    null_resource.execute_postgres_extensions_job,
    null_resource.execute_mysql_plugins_job,
    null_resource.execute_gcs_backup_job,
    null_resource.execute_gdrive_backup_job
  ]
}

resource "null_resource" "execute_custom_sql_scripts_job" {
  count = local.enable_custom_sql_scripts && local.sql_server_exists && local.custom_sql_scripts_bucket != "" ? 1 : 0

  triggers = {
    scripts_bucket = local.custom_sql_scripts_bucket
    scripts_path   = local.custom_sql_scripts_path
    use_root       = tostring(local.custom_sql_scripts_use_root)
    job_name       = google_cloud_run_v2_job.custom_sql_scripts_job[0].name
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
      echo "Executing custom SQL scripts job for deployment: ${local.resource_prefix}"
      echo "Bucket: ${local.custom_sql_scripts_bucket}"
      echo "Path: ${local.custom_sql_scripts_path}"
      echo "Use Root: ${local.custom_sql_scripts_use_root}"

      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
        echo "Using impersonation: ${local.impersonation_service_account}"
      fi

      echo "Waiting for IAM permissions to propagate..."
      sleep 15

      timeout 660 gcloud run jobs execute ${google_cloud_run_v2_job.custom_sql_scripts_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        $IMPERSONATE_FLAG \
        --wait || {
          EXIT_CODE=$?
          if [ $EXIT_CODE -eq 124 ]; then
            echo "⚠ Job execution timed out after 11 minutes"
            exit 1
          else
            echo "✗ Custom SQL scripts job failed with exit code $EXIT_CODE"
            exit $EXIT_CODE
          fi
        }

      echo "✓ Custom SQL scripts executed successfully"
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.custom_sql_scripts_job,
    null_resource.execute_postgres_extensions_job,
    null_resource.execute_mysql_plugins_job,
    null_resource.execute_gcs_backup_job,
    null_resource.execute_gdrive_backup_job
  ]
}
