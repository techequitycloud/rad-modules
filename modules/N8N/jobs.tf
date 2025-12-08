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
# Backup Jobs

resource "google_cloud_run_v2_job" "backup_service" {
  for_each   = { for k, v in local.environments : k => v if var.configure_backups && local.nfs_server_exists }
  project    = local.project.project_id
  name       = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}"
  location   = local.region
  deletion_protection = false

  template {
    parallelism = 1
    task_count  = 1

    labels = {
      app : var.application_name,
      env : each.key
    }

    template {
      service_account       = local.cloud_run_sa_email
      max_retries           = 3
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/backup:${var.application_version}"

        env {
          name  = "DB_USER"
          value = google_sql_user.user[each.key].name
        }

        env {
          name  = "DB_NAME"
          value = google_sql_database.db[each.key].name
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.db_password[each.key].secret_id
              version = "latest"
            }
          }
        }

        env {
          name  = "DB_HOST"
          value = "${local.db_internal_ip}"
        }

        volume_mounts {
          name      = "gcs-backup-volume"
          mount_path = "/data"
        }

        volume_mounts {
          name      = "nfs-data-volume"
          mount_path = "/mnt"
        }
      }

      vpc_access {
        network_interfaces {
          network = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
          tags = ["nfsserver"]
        }
      }

      volumes {
        name = "gcs-backup-volume"
        gcs {
          bucket = google_storage_bucket.backup_storage[each.key].name
        }
      }

      volumes {
        name = "nfs-data-volume"
        nfs {
          server = "${local.nfs_internal_ip}"
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.key}"
        }
      }
    }
  }

  depends_on = [
    null_resource.build_and_push_backup_image,
    google_sql_database.db,
    google_storage_bucket.backup_storage,
    null_resource.import_nfs
  ]
}
