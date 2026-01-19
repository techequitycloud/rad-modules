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
# VPC Access Connector for Serverless Services
#########################################################################

resource "google_vpc_access_connector" "serverless_connector" {
  count         = var.create_vpc_connector ? 1 : 0

  project       = local.project.project_id
  name          = "vpc-connector-${local.random_id}"
  region        = local.region

  # Network configuration
  network       = google_compute_network.vpc_network.name
  ip_cidr_range = var.vpc_connector_ip_cidr_range

  # Instance configuration
  machine_type  = var.vpc_connector_machine_type
  min_instances = var.vpc_connector_min_instances
  max_instances = var.vpc_connector_max_instances

  depends_on = [
    resource.time_sleep.wait_for_apis,
    google_compute_network.vpc_network,
    google_compute_subnetwork.gce_subnetwork,
  ]
}
