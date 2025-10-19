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
# Configure Redis
#########################################################################

resource "google_redis_cluster" "redis_instance" {
  name            = format("redis-%s", local.random_id) 
  shard_count     = 1

  psc_configs {
    network       = google_compute_network.vpc_network.id
  }

  region          = local.region
  replica_count   = 0
  node_type       = "REDIS_SHARED_CORE_NANO"
  transit_encryption_mode = "TRANSIT_ENCRYPTION_MODE_DISABLED"
  authorization_mode = "AUTH_MODE_DISABLED"

  redis_configs = {
    maxmemory-policy    = "volatile-ttl"
  }

  deletion_protection_enabled = false

  zone_distribution_config {
    mode = "SINGLE_ZONE"
    zone = data.google_compute_zones.available_zones.names[0] 
  }

  maintenance_policy {
    weekly_maintenance_window {
      day = "MONDAY"
      start_time {
        hours = 1
        minutes = 0
        seconds = 0
        nanos = 0
      }
    }
  }

  depends_on = [
    google_network_connectivity_service_connection_policy.default
  ]
}

resource "google_network_connectivity_service_connection_policy" "default" {
  name = "${google_redis_cluster.redis_instance.name}-redis-policy"
  location = local.region
  service_class = "gcp-memorystore-redis"
  description   = "Basic service connection policy"
  network = google_compute_network.vpc_network.id

  psc_config {
    subnetworks = [google_compute_subnetwork.gce_subnetwork.id]
  }
}
