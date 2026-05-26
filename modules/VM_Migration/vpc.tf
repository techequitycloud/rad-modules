/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

resource "google_compute_network" "lab_vpc" {
  count                   = var.create_vpc ? 1 : 0
  project                 = local.project.project_id
  name                    = local.peer_vpc_name
  auto_create_subnetworks = true
  description             = "VPC network for VM Migration lab — hosts the Windows MCDCv6 VM and Linux discovery targets"

  depends_on = [google_project_service.enabled_services]
}

# Data source used by firewall and compute resources to reference the VPC
# whether or not it was created by this module.
data "google_compute_network" "lab_vpc" {
  project = local.project.project_id
  name    = local.peer_vpc_name
  depends_on = [
    google_compute_network.lab_vpc,
  ]
}
