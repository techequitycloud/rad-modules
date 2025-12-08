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
# Create a Monitoring Policy
#########################################################################

resource "google_monitoring_uptime_check_config" "app_uptime_check" {
  for_each = { for k, v in local.service_instances : k => v if var.configure_monitoring }

  project      = local.project.project_id
  display_name = "uptime-check-${each.key}"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path = "/"
    port = 443
    use_ssl = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = local.project.project_id
      host       = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.value.env}-${local.project_number}.${each.value.region}.run.app"
    }
  }

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}

# Resource to introduce a delay after creating the cloud run service
resource "time_sleep" "app_service" {
  for_each = local.service_instances

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]

  create_duration = "30s"
}
