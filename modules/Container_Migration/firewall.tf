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

data "google_compute_network" "vpc" {
  project = local.project.project_id
  name    = local.vpc_name
  depends_on = [
    google_compute_network.vpc,
  ]
}

#########################################################################
# Default VPC Firewall Rules
#########################################################################

resource "google_compute_firewall" "allow_internal" {
  count   = var.create_default_firewall_rules ? 1 : 0
  project = local.project.project_id
  name    = "altostrat-${local.random_id}-allow-internal"
  network = data.google_compute_network.vpc.name

  direction = "INGRESS"
  priority  = 65534

  allow {
    protocol = "all"
  }

  source_ranges = [var.internal_traffic_cidr]
  description   = "Allow all internal traffic between VM instances within the VPC network"

  depends_on = [google_project_service.enabled_services]
}

resource "google_compute_firewall" "allow_ssh" {
  count   = var.create_default_firewall_rules ? 1 : 0
  project = local.project.project_id
  name    = "altostrat-${local.random_id}-allow-ssh"
  network = data.google_compute_network.vpc.name

  direction = "INGRESS"
  priority  = 65534

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  description   = "Allow SSH connections from any source to all instances"

  depends_on = [google_project_service.enabled_services]
}

resource "google_compute_firewall" "allow_icmp" {
  count   = var.create_default_firewall_rules ? 1 : 0
  project = local.project.project_id
  name    = "altostrat-${local.random_id}-allow-icmp"
  network = data.google_compute_network.vpc.name

  direction = "INGRESS"
  priority  = 65534

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  description   = "Allow ICMP traffic from any source to all instances"

  depends_on = [google_project_service.enabled_services]
}

#########################################################################
# Tomcat Firewall Rule — exposes port 8080 for browser access to the app
#########################################################################

resource "google_compute_firewall" "allow_tomcat" {
  project = local.project.project_id
  name    = "altostrat-${local.random_id}-allow-tomcat"
  network = data.google_compute_network.vpc.name

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["tomcat"]
  description   = "Allow HTTP traffic on port 8080 to Tomcat-tagged instances"

  depends_on = [google_project_service.enabled_services]
}
