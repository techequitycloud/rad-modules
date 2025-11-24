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

// ------------------------------------------------------------------
// VPC Network
// ------------------------------------------------------------------

resource "google_compute_network" "vpc" {
  project                 = local.project.project_id
  name                    = "${var.network_name}-${local.random_id}"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  depends_on = [
    google_project_service.enabled_services,
  ]
}

resource "google_compute_subnetwork" "subnetwork" {
  project                  = local.project.project_id
  name                     = "${var.subnet_name}-${local.random_id}"
  ip_cidr_range            = tolist(var.ip_cidr_ranges)[0]
  region                   = var.region
  network                  = google_compute_network.vpc.name
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = var.pod_ip_range
    ip_cidr_range = var.pod_cidr_block
  }

  secondary_ip_range {
    range_name    = var.service_ip_range
    ip_cidr_range = var.service_cidr_block
  }

  depends_on = [
    google_project_service.enabled_services,
    google_compute_network.vpc,
  ]
}

// ------------------------------------------------------------------
// Firewall Rules
// ------------------------------------------------------------------

resource "google_compute_firewall" "allow_lb_health_checks" {
  project = local.project.project_id
  name    = "fw-allow-lb-hc-${local.random_id}"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  depends_on    = [google_compute_network.vpc]
}

resource "google_compute_firewall" "allow_nfs_health_checks" {
  project = local.project.project_id
  name    = "fw-allow-nfs-hc-${local.random_id}"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports    = ["2049"]
  }
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  depends_on    = [google_compute_network.vpc]
}

resource "google_compute_firewall" "allow_iap_ssh" {
  project = local.project.project_id
  name    = "fw-allow-iap-ssh-${local.random_id}"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  depends_on    = [google_compute_network.vpc]
}

resource "google_compute_firewall" "allow_intra_vpc" {
  project = local.project.project_id
  name    = "fw-allow-intra-vpc-${local.random_id}"
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
  source_ranges = [var.pod_cidr_block]
  depends_on    = [google_compute_network.vpc]
}

// ------------------------------------------------------------------
// Cloud NAT
// ------------------------------------------------------------------

resource "google_compute_router" "router" {
  project = local.project.project_id
  name    = "cr-${var.region}-${local.random_id}"
  region  = google_compute_subnetwork.subnetwork.region
  network = google_compute_network.vpc.id
  bgp {
    asn = 64514
  }
  depends_on = [google_compute_network.vpc]
}

resource "google_compute_router_nat" "nat_gateway" {
  project                            = local.project.project_id
  name                               = "nat-gw-${var.region}-${local.random_id}"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
  depends_on = [google_compute_network.vpc]
}
