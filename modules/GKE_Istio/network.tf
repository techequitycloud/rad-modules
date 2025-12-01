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

# Resource definition for a VPC network
resource "google_compute_network" "vpc" {
  project                  = local.project.project_id  # Sets the project in which the resource will be created
  name                     = var.network_name          # The name of the network, referencing a variable
  auto_create_subnetworks  = false                     # Disables the automatic creation of subnetworks
  routing_mode             = "GLOBAL"                  # Sets the network routing mode to global
  depends_on               = [google_project_service.enabled_services]  # Ensures services are enabled before creating the network
}

# Resource definition for a subnet within the VPC network
resource "google_compute_subnetwork" "subnetwork" {
  project                  = local.project.project_id      # Sets the project in which the resource will be created
  name                     = "vpc-subnet"          # The name of the subnetwork
  ip_cidr_range            = tolist(var.ip_cidr_ranges)[0] # The IP range for the subnet, taking the first element from a list variable
  region                   = var.gcp_region            # The region where the subnet will be created
  network                  = google_compute_network.vpc.name # Reference to the VPC network's name
  private_ip_google_access = true                          # Enables instances in this subnet to access Google services without an external IP address

  # Adding a secondary range for pods in this subnet
  secondary_ip_range {
    range_name    = var.pod_ip_range   # The name for the secondary range, referencing a variable
    ip_cidr_range = var.pod_cidr_block      # The IP range for pods, referencing a variable
  }

  # Adding a secondary range for services in this subnet
  secondary_ip_range {
    range_name    = var.service_ip_range   # The name for the service range, referencing a variable
    ip_cidr_range = var.service_cidr_block      # The IP range for services, referencing a variable
  }

  depends_on      = [google_compute_network.vpc]  # Ensures services are enabled before creating the network
}

#########################################################################
# Firewall Rules in vpc
#########################################################################

# Firewall rule to allow Layer 7 Load Balancer health checks
resource "google_compute_firewall" "fw_allow_lb_hc" {
  project = local.project.project_id  # Project ID where the firewall rule will live
  name    = "fw-allow-lb-hc"         # Descriptive name of the firewall rule
  network = google_compute_network.vpc.name  # Reference to the VPC network

  # Allow traffic for health checks
  allow {
    protocol = "tcp"   # Protocol used for health checks
    ports    = ["80"]  # Port used for health checks
  }

  # Define source ranges that are allowed to perform health checks
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  depends_on    = [google_compute_network.vpc]  # Ensures services are enabled before creating the network
}

# Firewall rule to allow NFS health checks
resource "google_compute_firewall" "fw_allow_nfs_hc" {
  project = local.project.project_id   # Project ID where the firewall rule will live
  name    = "fw-allow-nfs-hc"          # Descriptive name of the firewall rule
  network = google_compute_network.vpc.name  # Reference to the VPC network

  # Allow NFS traffic
  allow {
    protocol = "tcp"   # Protocol used for NFS
    ports    = ["2049"] # NFS port to allow
  }

  # Define source ranges that are allowed to perform NFS health checks
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  depends_on    = [google_compute_network.vpc]  # Ensures services are enabled before creating the network
}

# Firewall rule to allow SSH connections via Identity-Aware Proxy (IAP)
resource "google_compute_firewall" "fw_allow_iap_ssh" {
  project = local.project.project_id   # Project ID where the firewall rule will live
  name    = "fw-allow-iap-ssh"         # Descriptive name of the firewall rule
  network = google_compute_network.vpc.name  # Reference to the VPC network

  # Allow SSH traffic
  allow {
    protocol = "tcp"   # Protocol used for SSH
    ports    = ["22"]   # SSH port to allow
  }

  # Define source ranges that are allowed to connect via IAP
  source_ranges = ["35.235.240.0/20"]
  depends_on    = [google_compute_network.vpc]  # Ensures services are enabled before creating the network
}

# Firewall rule to allow all traffic within the VPC network
resource "google_compute_firewall" "fw_allow_intra_vpc" {
  project = local.project.project_id   # Project ID where the firewall rule will live
  name    = "fw-allow-intra-vpc"       # Descriptive name of the firewall rule
  network = google_compute_network.vpc.name  # Reference to the VPC network

  # Allow all protocols and ports within the VPC
  allow {
    protocol = "all"
  }

  # Define source ranges within the VPC that are allowed unrestricted access
  source_ranges = var.ip_cidr_ranges
  depends_on    = [google_compute_network.vpc]  # Ensures services are enabled before creating the network
}

# Firewall rule to allow NFS service traffic on TCP protocol
resource "google_compute_firewall" "fw_allow_gce_nfs_tcp" {
  project = local.project.project_id   # Project ID where the firewall rule will live
  name    = "fw-allow-nfs-tcp"         # Descriptive name of the firewall rule
  network = google_compute_network.vpc.name  # Reference to the VPC network

  # Allow NFS traffic on TCP protocol
  allow {
    protocol = "tcp"
    ports    = ["2049"]
  }

  # Define source ranges that are allowed to connect to NFS service
  source_ranges = var.ip_cidr_ranges

  # Target tags used to apply this rule to instances with the 'nfs-server' tag
  target_tags   = ["nfs-server"]
  depends_on    = [google_compute_network.vpc]  # Ensures services are enabled before creating the network
}

# Firewall rule to allow HTTP and HTTPS service traffic on TCP protocol
resource "google_compute_firewall" "fw_allow_http_tcp" {
  project = local.project.project_id   # Project ID where the firewall rule will live
  name    = "fw-allow-http-tcp"        # Descriptive name of the firewall rule
  network = google_compute_network.vpc.name  # Reference to the VPC network

  # Allow HTTP and HTTPS traffic on TCP protocol
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  # Define source ranges that are allowed to connect to HTTP services
  source_ranges = var.ip_cidr_ranges

  # Target tags used to apply this rule to instances with the 'http-server' tag
  target_tags   = ["http-server"]
  depends_on    = [google_compute_network.vpc]  # Ensures services are enabled before creating the network
}

#########################################################################
# Creating Cloud NATs for Egress traffic from vpc
#########################################################################

# Define a Google Compute Router resource for the region
resource "google_compute_router" "cr_region" {
  project = local.project.project_id  # The project ID where the router will be created
  name    = "cr1-${var.gcp_region}"        # The name of the router, including the region variable
  region  = google_compute_subnetwork.subnetwork.region  # The region where the router will be located, taken from the subnet's region
  network = google_compute_network.vpc.id                # The ID of the VPC network to which this router belongs

  # BGP configuration block
  bgp {
    asn = 64514  # The Autonomous System Number (ASN) for BGP
  }
  depends_on = [google_compute_network.vpc]  # Ensures services are enabled before creating the network
}

# Define a Google Compute Router NAT for the region
resource "google_compute_router_nat" "nat_gw_region" {
  project                            = local.project.project_id  # The project ID where the NAT gateway will be created
  name                               = "nat-gw1-${var.gcp_region}"    # The name of the NAT gateway, including the region variable
  router                             = google_compute_router.cr_region.name  # The name of the router this NAT gateway is associated with
  region                             = google_compute_router.cr_region.region  # The region where the NAT gateway will be located
  nat_ip_allocate_option             = "AUTO_ONLY"               # NAT IP allocation mode set to automatically allocate IPs
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"  # NAT all IP ranges in all subnetworks

  # Logging configuration block
  log_config {
    enable = true              # Enable logging
    filter = "ERRORS_ONLY"     # Log only errors
  }
  depends_on = [google_compute_network.vpc]  # Ensures services are enabled before creating the network
}