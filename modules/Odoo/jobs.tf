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

# ============================================================================
# Import DB Job
# ============================================================================

resource "google_cloud_run_v2_job" "import_db_job" {
  count      = local.sql_server_exists ? 1 : 0
  project    = local.project.project_id
  name       = "import-db-${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  location   = local.region
  deletion_protection = false

  template {
    template {
      service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries     = 0
      timeout         = "600s"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "alpine:3.19"

        env {
          name  = "DB_HOST"
          value = "${local.db_internal_ip}"
        }
        env {
          name  = "DB_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        }
        env {
          name  = "DB_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        }

        env {
          name = "ROOT_PASS"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-root-password"
              version = "latest"
            }
          }
        }

        env {
          name = "DB_PASS"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}-password-${var.tenant_deployment_id}-${local.random_id}"
              version = "latest"
            }
          }
        }

        command = ["/bin/sh"]
        args = ["-c", file("${path.module}/scripts/app/import_db_job.sh")]
      }

      vpc_access {
        network_interfaces {
          network = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
        }
      }
    }
  }
}

resource "null_resource" "execute_import_db_job" {
  count = local.sql_server_exists ? 1 : 0

  triggers = {
    job_id = google_cloud_run_v2_job.import_db_job[0].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      echo "Executing DB import job..."
      gcloud run jobs execute ${google_cloud_run_v2_job.import_db_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        --wait

      if [ $? -eq 0 ]; then
        echo "✓ DB import/init job completed successfully"
      else
        echo "✗ DB import/init job failed"
        exit 1
      fi
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.import_db_job,
    google_secret_manager_secret_version.db_password
  ]
}
