/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law of agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

resource "google_compute_network" "vpc" {
  project                         = local.project.project_id
  name                            = var.network_name
  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
  mtu                             = 1500
}

resource "google_compute_subnetwork" "subnetwork" {
  for_each      = local.cluster_configs
  project       = local.project.project_id
  name          = "${var.subnet_name}-${each.key}"
  ip_cidr_range = each.value.ip_cidr_range
  region        = each.value.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = each.value.pod_ip_range
    ip_cidr_range = each.value.pod_cidr_block
  }

  secondary_ip_range {
    range_name    = each.value.service_ip_range
    ip_cidr_range = each.value.service_cidr_block
  }
}

resource "google_compute_router" "router" {
  for_each  = local.cluster_configs
  project   = local.project.project_id
  name      = "router-${each.key}"
  region    = each.value.region
  network   = google_compute_network.vpc.id
  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat_gateway" {
  for_each                               = local.cluster_configs
  project                                = local.project.project_id
  name                                   = "nat-gateway-${each.key}"
  router                                 = google_compute_router.router[each.key].name
  region                                 = google_compute_router.router[each.key].region
  source_subnetwork_ip_ranges_to_nat     = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_address" "static_ip" {
  for_each     = local.cluster_configs
  project      = local.project.project_id
  name         = "static-ip-${each.key}"
  region       = each.value.region
  address_type = "EXTERNAL"
}

resource "google_compute_firewall" "allow_ssh" {
  project       = local.project.project_id
  name          = "allow-ssh"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_internal" {
  project       = local.project.project_id
  name          = "allow-internal"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  source_ranges = [for config in local.cluster_configs : config.ip_cidr_range]
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
}

resource "google_compute_firewall" "allow_gke_masters" {
  project       = local.project.project_id
  name          = "allow-gke-masters"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  source_ranges = ["172.16.0.0/28"] # GKE masters default range
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
}

resource "google_compute_firewall" "allow_health_checks" {
  project       = local.project.project_id
  name          = "allow-health-checks"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"] # Google Cloud health checkers
  allow {
    protocol = "tcp"
  }
}
