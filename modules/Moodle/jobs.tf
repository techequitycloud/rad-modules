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
# DB Import Jobs
#########################################################################

resource "google_cloud_run_v2_job" "db_import_job" {
  for_each = local.sql_server_exists ? local.enabled_envs : toset([])

  project    = local.project.project_id
  name       = "import${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}"
  location   = local.region
  deletion_protection = false

  template {
    parallelism = 1
    task_count  = 1

    labels = {
      app = var.application_name,
      env = each.key
    }

    template {
      service_account       = local.cloud_run_sa_email
      max_retries           = 3
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        # Re-using backup image as it has psql and tools
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/backup:${var.application_version}"

        # Override entrypoint to run import script
        command = ["/usr/local/bin/import-db.sh"]

        env {
          name  = "DB_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.key}"
        }

        env {
          name  = "DB_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.key}"
        }

        env {
          name = "DB_PASS"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.db_password[each.key].secret_id
              version = "latest"
            }
          }
        }

        env {
          name = "PG_PASS"
          value = local.db_root_password
        }

        env {
          name  = "DB_IP"
          value = local.db_internal_ip
        }

        env {
          name  = "BACKUP_FILEID"
          value = var.application_backup_fileid
        }

        env {
          name  = "PROJECT_ID"
          value = local.project.project_id
        }
      }

      vpc_access {
        network_interfaces {
          network = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
        }
      }
    }
  }

  depends_on = [
    null_resource.build_and_push_backup_image,
    google_secret_manager_secret_version.db_password,
  ]
}

# Resource to trigger the job immediately after creation
resource "null_resource" "trigger_db_import" {
  for_each = google_cloud_run_v2_job.db_import_job

  triggers = {
    job_id = each.value.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = "gcloud run jobs execute ${each.value.name} --project ${local.project.project_id} --region ${local.region} --wait"
  }
}
