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
# Redis Instance (Memorystore)
#########################################################################

resource "google_redis_instance" "cache" {
  count              = var.create_redis ? 1 : 0

  project            = local.project.project_id
  name               = "redis-cache-${local.random_id}"
  tier               = var.redis_tier
  memory_size_gb     = var.redis_memory_size_gb
  region             = local.region

  # Network configuration
  authorized_network = google_compute_network.vpc_network.id
  connect_mode       = var.redis_connect_mode

  # Redis version
  redis_version      = var.redis_version

  # Configuration
  display_name       = "Application Cache"

  labels = merge(
    var.resource_labels,
    {
      environment = "production"
      managed-by  = "terraform"
    }
  )

  # Maintenance policy
  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours   = 2
        minutes = 0
        seconds = 0
        nanos   = 0
      }
    }
  }

  depends_on = [
    resource.time_sleep.wait_for_apis,
    google_compute_network.vpc_network,
    google_service_networking_connection.psconnect,
  ]
}

#########################################################################
# Store Redis connection details in Secret Manager
#########################################################################

resource "google_secret_manager_secret" "redis_host" {
  count      = var.create_redis ? 1 : 0

  project    = local.project.project_id
  secret_id  = "redis-host-${local.random_id}"

  labels = var.resource_labels

  replication {
    auto {}
  }

  depends_on = [
    google_redis_instance.cache,
  ]
}

resource "google_secret_manager_secret_version" "redis_host" {
  count       = var.create_redis ? 1 : 0

  secret      = google_secret_manager_secret.redis_host[0].id
  secret_data = google_redis_instance.cache[0].host

  depends_on = [
    google_secret_manager_secret.redis_host,
  ]
}

resource "google_secret_manager_secret" "redis_port" {
  count      = var.create_redis ? 1 : 0

  project    = local.project.project_id
  secret_id  = "redis-port-${local.random_id}"

  labels = var.resource_labels

  replication {
    auto {}
  }

  depends_on = [
    google_redis_instance.cache,
  ]
}

resource "google_secret_manager_secret_version" "redis_port" {
  count       = var.create_redis ? 1 : 0

  secret      = google_secret_manager_secret.redis_port[0].id
  secret_data = tostring(google_redis_instance.cache[0].port)

  depends_on = [
    google_secret_manager_secret.redis_port,
  ]
}
