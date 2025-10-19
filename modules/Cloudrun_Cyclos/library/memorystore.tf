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

locals {
  redis_instance = format("redis-db-%s", local.random_id)
}

resource "google_redis_instance" "redis_instance" {
  count          = var.create_redis ? 1 : 0
  project        = local.project.project_id
  name           = local.redis_instance
  tier           = "BASIC"
  memory_size_gb = 1
  region         = local.region
  redis_version  = "REDIS_6_X"

  location_id    = "${local.region}-b"

  authorized_network = "https://www.googleapis.com/compute/v1/projects/${local.configuration[var.project_environment].host_project_id}/global/networks/${var.network_name}"
  connect_mode       = "DIRECT_PEERING"

  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours = 0
        minutes = 30
        seconds = 0
        nanos = 0
      }
    }
  }

  persistence_config {
    persistence_mode = "RDB"
    rdb_snapshot_period = "TWENTY_FOUR_HOURS"
  }

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    module.foundation_platform,
    module.vpc,
    google_project_service.enabled_services,
  ]
}
