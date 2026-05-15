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

# Data source to resolve the peer VPC so all firewall rules reference a known network self-link.
data "google_compute_network" "peer_vpc" {
  project = local.project.project_id
  name    = local.peer_vpc_name
  depends_on = [
    google_compute_network.peer_vpc,
  ]
}

#########################################################################
# Default VPC Firewall Rules
# These mirror the four rules Google auto-creates on the default VPC.
# Set create_default_firewall_rules = false if they already exist on
# the target network to avoid a duplicate-resource error.
#########################################################################

# Allows all internal traffic between VM instances within the VPC.
resource "google_compute_firewall" "default_allow_internal" {
  count   = var.create_default_firewall_rules ? 1 : 0
  project = local.project.project_id
  name    = "altostrat-${local.random_id}-allow-internal"
  network = data.google_compute_network.peer_vpc.name

  direction = "INGRESS"
  priority  = 65534

  allow {
    protocol = "all"
  }

  source_ranges = [var.internal_traffic_cidr]
  description   = "Allow all internal traffic between VM instances within the VPC network"

  depends_on = [google_project_service.enabled_services, google_compute_network.peer_vpc]
}

# Allows SSH access from any source to all instances.
resource "google_compute_firewall" "default_allow_ssh" {
  count   = var.create_default_firewall_rules ? 1 : 0
  project = local.project.project_id
  name    = "altostrat-${local.random_id}-allow-ssh"
  network = data.google_compute_network.peer_vpc.name

  direction = "INGRESS"
  priority  = 65534

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  description   = "Allow SSH connections from any source to all instances"

  depends_on = [google_project_service.enabled_services, google_compute_network.peer_vpc]
}

# Allows RDP access from any source to all Windows instances.
resource "google_compute_firewall" "default_allow_rdp" {
  count   = var.create_default_firewall_rules ? 1 : 0
  project = local.project.project_id
  name    = "altostrat-${local.random_id}-allow-rdp"
  network = data.google_compute_network.peer_vpc.name

  direction = "INGRESS"
  priority  = 65534

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  source_ranges = ["0.0.0.0/0"]
  description   = "Allow RDP connections from any source to all Windows instances"

  depends_on = [google_project_service.enabled_services, google_compute_network.peer_vpc]
}

# Allows ICMP (ping) traffic from any source to all instances.
resource "google_compute_firewall" "default_allow_icmp" {
  count   = var.create_default_firewall_rules ? 1 : 0
  project = local.project.project_id
  name    = "altostrat-${local.random_id}-allow-icmp"
  network = data.google_compute_network.peer_vpc.name

  direction = "INGRESS"
  priority  = 65534

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  description   = "Allow ICMP traffic from any source to all instances"

  depends_on = [google_project_service.enabled_services, google_compute_network.peer_vpc]
}

#########################################################################
# Jump Host Firewall Rule
#########################################################################

# Allows HTTP and HTTPS traffic from any source to instances tagged jump-host.
# Required for the Windows bastion host to serve Cloud Shell and browser sessions.
resource "google_compute_firewall" "default_allow_http" {
  project = local.project.project_id
  name    = "altostrat-${local.random_id}-allow-http"
  network = data.google_compute_network.peer_vpc.name

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jump-host"]
  description   = "Allow HTTP and HTTPS traffic from any source to jump-host tagged instances"

  depends_on = [google_project_service.enabled_services, google_compute_network.peer_vpc]
}
