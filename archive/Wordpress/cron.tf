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

resource "google_cloud_scheduler_job" "wp_cron" {
  for_each         = var.configure_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])
  name             = "wp-cron-${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  description      = "Trigger WordPress Cron"
  schedule         = "*/5 * * * *"
  time_zone        = "Etc/UTC"
  attempt_deadline = "320s"
  region           = each.key
  project          = local.project.project_id

  http_target {
    http_method = "GET"
    uri         = "${google_cloud_run_v2_service.app_service[each.key].uri}/wp-cron.php?doing_wp_cron"

    oidc_token {
      service_account_email = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
    }
  }

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}
