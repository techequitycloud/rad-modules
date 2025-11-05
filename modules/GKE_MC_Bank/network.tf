/**
 * Copyright 2023 Google LLC
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

# Creates the VPC network
resource "google_compute_network" "vpc" {
  project                         = local.project.project_id
  name                            = var.network_name
  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
}

# Creates the subnetwork
resource "google_compute_subnetwork" "subnetwork" {
  for_each      = var.cluster_configs
  project       = local.project.project_id
  name          = "${var.subnet_name}-${each.key}"
  ip_cidr_range = each.value.ip_cidr_range
  network       = google_compute_network.vpc.name
  region        = each.value.region

  secondary_ip_range {
    range_name    = each.value.pod_ip_range
    ip_cidr_range = each.value.pod_cidr_block
  }

  secondary_ip_range {
    range_name    = each.value.service_ip_range
    ip_cidr_range = each.value.service_cidr_block
  }
}

# Creates the Cloud Router
resource "google_compute_router" "router" {
  for_each  = var.cluster_configs
  project   = local.project.project_id
  name      = "router-${each.key}"
  network   = google_compute_network.vpc.name
  region    = each.value.region
  bgp {
    asn = 64514
  }
}

# Creates the Cloud NAT
resource "google_compute_router_nat" "nat" {
  for_each                           = var.cluster_configs
  project                            = local.project.project_id
  name                               = "nat-${each.key}"
  router                             = google_compute_router.router[each.key].name
  region                             = each.value.region
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.subnetwork[each.key].id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Creates the firewall rules
resource "google_compute_firewall" "allow_ssh" {
  project = local.project.project_id
  name    = "allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_rdp" {
  project = local.project.project_id
  name    = "allow-rdp"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_icmp" {
  project = local.project.project_id
  name    = "allow-icmp"
  network = google_compute_network.vpc.name

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_internal" {
  project = local.project.project_id
  name    = "allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [for config in var.cluster_configs : config.ip_cidr_range]
}

resource "google_compute_firewall" "allow_health_checks" {
  project = local.project.project_id
  name    = "allow-health-checks"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}
