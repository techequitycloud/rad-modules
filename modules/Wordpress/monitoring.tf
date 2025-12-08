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
# Create Uptime checks
#########################################################################

# Resource for creating an uptime check config for the application
resource "google_monitoring_uptime_check_config" "app_uptime_check" {
  # Iterating over the consolidated service instances
  for_each = var.configure_monitoring ? {
    for instance in local.service_instances : instance.key => instance
  } : {}

  project      = local.project.project_id
  display_name = "uptime-check-${each.value.name}"
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
      host       = trimsuffix(trimprefix(google_cloud_run_v2_service.app_service[each.key].uri, "https://"), "/")
    }
  }

  depends_on = [
    time_sleep.app_service_wait
  ]
}

# Wait for service to be ready before creating uptime check
resource "time_sleep" "app_service_wait" {
  # Iterating over the consolidated service instances
  for_each = var.configure_monitoring ? {
    for instance in local.service_instances : instance.key => instance
  } : {}

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]

  create_duration = "60s"
}
