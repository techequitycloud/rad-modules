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
    for job in var.initialization_jobs :
    job.name => job
  }

  # Determine subnet for the region
  subnet_map = local.region_to_subnet
}

# ============================================================================
# NFS Setup Job (Default)
# ============================================================================

resource "google_cloud_run_v2_job" "nfs_setup_job" {
  count               = local.nfs_enabled && local.nfs_server_exists ? 1 : 0
  project             = local.project.project_id
  name                = "nfs-setup-${local.resource_prefix}"
  location            = local.region
  deletion_protection = false

  template {
    template {
      service_account       = local.cloud_run_sa_email
      max_retries           = 0
      timeout               = "600s"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "alpine:3.19"

        env {
          name  = "DIR_NAME"
          value = local.resource_prefix
        }

        command = ["/bin/sh"]
        args    = ["-c", file("${path.module}/scripts/app/nfs_setup_job.sh")]

        volume_mounts {
          name       = "nfs-root-volume"
          mount_path = "/mnt/nfs"
        }
      }

      volumes {
        name = "nfs-root-volume"
        nfs {
          server = local.nfs_internal_ip
          path   = "/share"
        }
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${local.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_map[local.region]}"
        }
        egress = local.vpc_egress_setting
      }
    }
  }
}

resource "null_resource" "execute_nfs_setup_job" {
  count = local.nfs_enabled && local.nfs_server_exists ? 1 : 0

  triggers = {
    script_hash = filesha256("${path.module}/scripts/app/nfs_setup_job.sh")
    dir_name    = local.resource_prefix
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
      echo "Executing NFS setup job..."

      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
        echo "Using impersonation: ${local.impersonation_service_account}"
      fi

      echo "Waiting for IAM permissions to propagate..."
      sleep 15

      gcloud run jobs execute ${google_cloud_run_v2_job.nfs_setup_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        $IMPERSONATE_FLAG \
        --wait

      if [ $? -eq 0 ]; then
        echo "✓ NFS setup job completed successfully"
      else
        echo "✗ NFS setup job failed"
        exit 1
      fi
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
  name                = "${each.key}-${local.resource_prefix}"
  location            = local.region
  deletion_protection = false

  template {
    template {
      service_account       = local.cloud_run_sa_email
      max_retries           = each.value.max_retries
      timeout               = "${each.value.timeout_seconds}s"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
      task_count            = each.value.task_count

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

        # NFS volume mount (if enabled)
        dynamic "volume_mounts" {
          for_each = each.value.mount_nfs && local.nfs_enabled && local.nfs_server_exists ? [1] : []
          content {
            name       = local.nfs_volume_name
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

      # NFS volume (if enabled)
      dynamic "volumes" {
        for_each = each.value.mount_nfs && local.nfs_enabled && local.nfs_server_exists ? [1] : []
        content {
          name = local.nfs_volume_name
          nfs {
            server = local.nfs_internal_ip
            path   = local.nfs_share_path
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
        }
        egress = local.vpc_egress_setting
      }
    }
  }

  # Dependencies on secrets
  depends_on = [
    data.google_secret_manager_secret_version.db_password,
    google_secret_manager_secret.additional_secrets
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
      echo "Executing initialization job: ${each.key}..."

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
    null_resource.execute_nfs_setup_job
  ]
}
