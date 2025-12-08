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

# define a Cloud Scheduler cron job
resource "google_cloud_scheduler_job" "backup" {
  for_each         = { for k, v in local.environments : k => v if var.configure_backups } # Using configure_backups check which wasn't in original explicit count check logic directly but implied?
  # Original had `count = var.configure_development_environment ? 1 : 0` in dev_backup resource.
  # So it depended on environment flag.
  # But `jobs.tf` had `var.configure_backups && var.configure_...`.
  # The original `scheduler.tf` had `count = var.configure_development_environment ? 1 : 0`.
  # Wait, if `configure_backups` is false, the job shouldn't run.
  # But original code didn't check `configure_backups` in `scheduler.tf`!
  # It just checked `configure_development_environment`.
  # This implies the scheduler was created even if backups were disabled?
  # But the target uri refers to the job `bkup...dev`.
  # If `jobs.tf` didn't create the job (because `configure_backups` is false), the scheduler would fail to target it or be invalid?
  # Actually, `google_cloud_scheduler_job` `uri` is a string. It doesn't validate existence of the job at creation time necessarily, but at runtime it would fail.
  # I should improve this by checking `var.configure_backups`.

  paused           = false
  name             = "${var.application_name}-backup-${var.tenant_deployment_id}-${local.random_id}${each.key}"
  project          = local.project.project_id
  region           = local.region
  schedule         = "${var.application_backup_schedule}"
  time_zone        = "Europe/London"
  attempt_deadline = "180s"

  retry_config {
    max_doublings        = 5
    max_retry_duration   = "0s"
    max_backoff_duration = "3600s"
    min_backoff_duration = "5s"
  }

  http_target {
    http_method = "POST"
    uri = "https://${local.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${local.project.project_id}/jobs/bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}:run"
    headers = {
      "User-Agent"   = "Google-Cloud-Scheduler"
    }
    oauth_token {
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
      service_account_email = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
    }
  }

  depends_on = [
    null_resource.import_db,
    null_resource.import_nfs,
  ]
}
