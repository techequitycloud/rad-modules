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

#########################################################################
# vpc - VPC Network & Subnests
#########################################################################

# VPC resource - NO dependency on cleanup resource
resource "google_compute_network" "vpc" {
  project                  = local.project.project_id
  name                     = var.network_name
  auto_create_subnetworks  = false
  routing_mode             = "GLOBAL"
  
  depends_on = [
    google_project_service.enabled_services,
  ]
}

# Subnet resource - NO dependency on cleanup resource
resource "google_compute_subnetwork" "subnetwork" {
  project                  = local.project.project_id
  name                     = var.subnet_name
  ip_cidr_range            = var.ip_cidr_range
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

#########################################################################
# Firewall Rules in vpc
#########################################################################

# Firewall rule to allow Layer 7 Load Balancer health checks
resource "google_compute_firewall" "fw_allow_lb_hc" {
  project = local.project.project_id
  name    = "fw-allow-lb-hc"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  depends_on    = [google_compute_network.vpc]
}

# Firewall rule to allow NFS health checks
resource "google_compute_firewall" "fw_allow_nfs_hc" {
  project = local.project.project_id
  name    = "fw-allow-nfs-hc"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["2049"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  depends_on    = [google_compute_network.vpc]
}

# Firewall rule to allow SSH connections via Identity-Aware Proxy (IAP)
resource "google_compute_firewall" "fw_allow_iap_ssh" {
  project = local.project.project_id
  name    = "fw-allow-iap-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  depends_on    = [google_compute_network.vpc]
}

# Note: The 'fw_allow_intra_vpc' rule, which previously allowed all traffic from the pod CIDR range,
# has been removed. GKE's default networking configuration implicitly allows pod-to-pod communication
# within the cluster, making this rule redundant and overly permissive.
# For more details, see the GKE networking documentation: https://cloud.google.com/kubernetes-engine/docs/concepts/network-overview

# Firewall rule to allow NFS service traffic on TCP protocol
resource "google_compute_firewall" "fw_allow_gce_nfs_tcp" {
  project = local.project.project_id
  name    = "fw-allow-nfs-tcp"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["2049"]
  }

  source_ranges = [var.ip_cidr_range]
  target_tags   = ["nfs-server"]
  depends_on    = [google_compute_network.vpc]
}

# Firewall rule to allow HTTP and HTTPS service traffic on TCP protocol
resource "google_compute_firewall" "fw_allow_http_tcp" {
  project = local.project.project_id
  name    = "fw-allow-http-tcp"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = [var.ip_cidr_range]
  target_tags   = ["http-server"]
  depends_on    = [google_compute_network.vpc]
}

#########################################################################
# Creating Cloud NATs for Egress traffic from vpc
#########################################################################

# Define a Google Compute Router resource for the region
resource "google_compute_router" "cr_region" {
  project = local.project.project_id
  name    = "cr1-${var.region}"
  region  = google_compute_subnetwork.subnetwork.region
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }
  
  depends_on = [google_compute_network.vpc]
}

# Define a Google Compute Router NAT for the region
resource "google_compute_router_nat" "nat_gw_region" {
  project                            = local.project.project_id
  name                               = "nat-gw1-${var.region}"
  router                             = google_compute_router.cr_region.name
  region                             = google_compute_router.cr_region.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
  
  depends_on = [google_compute_network.vpc]
}
