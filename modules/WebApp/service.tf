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
# Image Build Gate
# This resource acts as a conditional dependency gate for image builds
#########################################################################

resource "null_resource" "image_build_gate" {
  count = var.configure_environment ? 1 : 0

  # This resource doesn't execute anything, it just serves as a dependency gate
  triggers = {
    container_image = local.container_image
    timestamp       = timestamp()
  }

  # Conditionally depend on build resources based on configuration
  depends_on = [
    # Depend on placeholder image build if CI/CD is enabled with custom image
    # Note: Uses concat to create conditional dependency list
  ]

  # Add explicit lifecycle to handle dependencies
  lifecycle {
    replace_triggered_by = []
  }
}

# Conditional dependency on CI/CD trigger setup
# When CI/CD is enabled, we use the default hello world image initially
# The CI/CD pipeline will deploy the actual application image on first push
resource "null_resource" "cicd_image_dependency" {
  count = var.configure_environment && local.enable_cicd_trigger && local.container_image_source == "custom" ? 1 : 0

  triggers = {
    trigger_ready = timestamp()
  }

  depends_on = [
    google_cloudbuild_trigger.cicd_trigger
  ]
}

# Conditional dependency on custom build
resource "null_resource" "custom_build_dependency" {
  count = var.configure_environment && local.enable_custom_build && !local.enable_cicd_trigger ? 1 : 0

  triggers = {
    build_complete = timestamp()
  }

  depends_on = [
    null_resource.build_and_push_application_image
  ]
}

#########################################################################
# Cloud Run Service
#########################################################################

resource "google_cloud_run_v2_service" "app_service" {
  count = var.configure_environment ? 1 : 0

  project             = local.project.project_id
  name                = local.service_name
  location            = local.region
  deletion_protection = false
  description         = var.application_description
  ingress             = upper("INGRESS_TRAFFIC_${replace(upper(local.ingress_settings), "-", "_")}")

  # Annotations
  annotations = var.service_annotations

  template {
    service_account       = local.cloud_run_sa_email
    session_affinity      = true
    execution_environment = upper("EXECUTION_ENVIRONMENT_${upper(var.execution_environment)}")
    timeout               = "${var.timeout_seconds}s"

    labels = merge(
      local.common_labels,
      var.service_labels,
      {
        app = local.application_name
      }
    )

    # Scaling configuration
    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    # Container configuration
    containers {
      image = local.container_image

      # Port configuration
      ports {
        name           = var.container_protocol
        container_port = var.container_port
      }

      # Resource limits
      resources {
        startup_cpu_boost = true
        cpu_idle          = var.min_instance_count == 0
        limits = {
          cpu    = var.container_resources.cpu_limit
          memory = var.container_resources.memory_limit
        }
        # Optional: requests
        # requests = {
        #   cpu    = var.container_resources.cpu_request
        #   memory = var.container_resources.mem_request
        # }
      }

      # Startup probe
      dynamic "startup_probe" {
        for_each = var.startup_probe_config.enabled ? [1] : []
        content {
          initial_delay_seconds = var.startup_probe_config.initial_delay_seconds
          timeout_seconds       = var.startup_probe_config.timeout_seconds
          period_seconds        = var.startup_probe_config.period_seconds
          failure_threshold     = var.startup_probe_config.failure_threshold

          dynamic "http_get" {
            for_each = upper(var.startup_probe_config.type) == "HTTP" ? [1] : []
            content {
              path = var.startup_probe_config.path
              port = var.container_port
            }
          }

          dynamic "tcp_socket" {
            for_each = upper(var.startup_probe_config.type) == "TCP" ? [1] : []
            content {
              port = var.container_port
            }
          }
        }
      }

      # Liveness probe
      dynamic "liveness_probe" {
        for_each = var.health_check_config.enabled ? [1] : []
        content {
          initial_delay_seconds = var.health_check_config.initial_delay_seconds
          timeout_seconds       = var.health_check_config.timeout_seconds
          period_seconds        = var.health_check_config.period_seconds
          failure_threshold     = var.health_check_config.failure_threshold

          dynamic "http_get" {
            for_each = upper(var.health_check_config.type) == "HTTP" ? [1] : []
            content {
              path = var.health_check_config.path
              port = var.container_port
            }
          }

          dynamic "tcp_socket" {
            for_each = upper(var.health_check_config.type) == "TCP" ? [1] : []
            content {
              port = var.container_port
            }
          }
        }
      }

      # Static environment variables
      dynamic "env" {
        for_each = merge(
          local.static_env_vars,
          # Add database host if SQL server exists
          local.sql_server_exists ? { DB_HOST = local.db_internal_ip } : {}
        )
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret environment variables
      dynamic "env" {
        for_each = local.secret_env_var_map
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

      # NFS volume mount
      dynamic "volume_mounts" {
        for_each = local.nfs_enabled && local.nfs_server_exists ? [1] : []
        content {
          name       = local.nfs_volume_name
          mount_path = local.nfs_mount_path
        }
      }

      # GCS volume mounts
      dynamic "volume_mounts" {
        for_each = local.gcs_volumes
        content {
          name       = volume_mounts.value.name
          mount_path = volume_mounts.value.mount_path
        }
      }
    }

    # NFS volume definition
    dynamic "volumes" {
      for_each = local.nfs_enabled && local.nfs_server_exists ? [1] : []
      content {
        name = local.nfs_volume_name
        nfs {
          server = local.nfs_internal_ip
          path   = local.nfs_share_path
        }
      }
    }

    # GCS volumes definition
    dynamic "volumes" {
      for_each = local.gcs_volumes
      content {
        name = volumes.value.name
        gcs {
          bucket        = volumes.value.bucket_name
          read_only     = volumes.value.readonly
          mount_options = volumes.value.mount_options
        }
      }
    }

    # VPC access configuration
    dynamic "vpc_access" {
      for_each = local.network_exists ? [1] : []
      content {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${local.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_map[local.region]}"
          tags       = local.network_tags
        }
        egress = local.vpc_egress_setting
      }
    }
  }

  # Traffic routing
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag     = "latest"
    percent = 100
  }

  depends_on = [
    data.google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_iam_member.db_password,
    google_secret_manager_secret_iam_member.additional_secrets,
    null_resource.execute_nfs_setup_job,
    null_resource.execute_initialization_jobs,
    null_resource.cicd_image_dependency,
    null_resource.custom_build_dependency,
  ]
}

#########################################################################
# IAM Policy for Cloud Run Service
#########################################################################

resource "google_cloud_run_service_iam_binding" "app" {
  count = var.configure_environment ? 1 : 0

  project  = local.project.project_id
  location = local.region
  service  = google_cloud_run_v2_service.app_service[0].name
  role     = "roles/run.invoker"
  members  = ["allUsers"]

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}
