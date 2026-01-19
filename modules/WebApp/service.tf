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

resource "google_cloud_run_v2_service" "app_service" {
  count               = var.configure_environment ? 1 : 0
  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  location            = local.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = local.cloud_run_sa_email
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    containers {
      image = var.application_image

      ports {
        container_port = var.application_port
      }

      resources {
        startup_cpu_boost = true
        cpu_idle = true
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
      }

      # Standard DB Env Vars
      dynamic "env" {
        for_each = local.sql_server_exists ? [1] : []
        content {
          name  = "DB_HOST"
          value = local.db_internal_ip
        }
      }
      dynamic "env" {
        for_each = local.sql_server_exists ? [1] : []
        content {
          name  = "DB_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        }
      }
      dynamic "env" {
        for_each = local.sql_server_exists ? [1] : []
        content {
          name  = "DB_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        }
      }
      dynamic "env" {
        for_each = local.sql_server_exists ? [1] : []
        content {
          name = "DB_PASS"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}-password-${var.tenant_deployment_id}-${local.random_id}"
              version = "latest"
            }
          }
        }
      }

      # User defined Env Vars
      dynamic "env" {
        for_each = var.application_env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # NFS Mount
      dynamic "volume_mounts" {
        for_each = local.nfs_server_exists ? [1] : []
        content {
          name       = "nfs-data-volume"
          mount_path = var.nfs_mount_path
        }
      }

      # GCS Mount
      dynamic "volume_mounts" {
        for_each = var.create_cloud_storage ? [1] : []
        content {
          name       = "gcs-data-volume"
          mount_path = "/mnt/gcs"
        }
      }
    }

    vpc_access {
      network_interfaces {
        network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
        subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_map[local.region]}"
        tags = local.nfs_server_exists ? ["nfsserver"] : []
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    dynamic "volumes" {
      for_each = local.nfs_server_exists ? [1] : []
      content {
        name = "nfs-data-volume"
        nfs {
          server = local.nfs_internal_ip
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        }
      }
    }

    dynamic "volumes" {
      for_each = var.create_cloud_storage ? [1] : []
      content {
        name = "gcs-data-volume"
        gcs {
          bucket = local.data_bucket_name
          mount_options = [
             "uid=1000", "gid=1000", "file-mode=644", "dir-mode=755", "implicit-dirs"
          ]
        }
      }
    }
  }

  depends_on = [
    null_resource.execute_import_db_job,
    null_resource.execute_nfs_setup_job,
    google_secret_manager_secret_iam_member.db_password,
  ]
}

resource "google_cloud_run_service_iam_binding" "app" {
  count    = var.configure_environment ? 1 : 0
  project  = local.project.project_id
  location = local.region
  service  = google_cloud_run_v2_service.app_service[0].name
  role     = "roles/run.invoker"
  members  = ["allUsers"]
  depends_on = [google_cloud_run_v2_service.app_service]
}
