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
# Create a cron job to trigger the backup
#########################################################################

resource "google_cloud_scheduler_job" "backup_job" {
  for_each = var.configure_backups ? local.enabled_envs : toset([])

  project     = local.project.project_id
  region      = local.region
  name        = "job${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}-backup"
  description = "Trigger Cloud Run job for backup"
  schedule    = var.application_backup_schedule
  time_zone   = "Etc/UTC"

  http_target {
    http_method = "POST"
    uri         = "https://${local.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${local.project.project_id}/jobs/bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}:run"

    oauth_token {
      service_account_email = local.cloud_run_sa_email
    }
  }

  depends_on = [
    google_cloud_run_v2_job.backup_service,
    google_cloud_run_v2_job.db_import_job, # Replaced null_resource dep
  ]
}
