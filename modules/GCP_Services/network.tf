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

########################################################################################
# Local variables for network resources
########################################################################################

locals {
  network_name   = var.network_name
  vpc_network_id = google_compute_network.vpc_network.id
  gce_subnet_id  = google_compute_subnetwork.gce_subnetwork[local.region].id
}

########################################################################################
# Create VPC network if it doesn't exist
########################################################################################

resource "google_compute_network" "vpc_network" {
  name                    = local.network_name
  project                 = local.project.project_id
  auto_create_subnetworks = false

  depends_on   = [
    google_service_account.cloud_run_sa_admin,
    google_service_account.cloud_build_sa_admin,
    google_service_account.nfs_server_sa_admin,
  ]
}

#########################################################################
# Create GCE subnetworks only if VPC doesn't exist
#########################################################################

resource "google_compute_subnetwork" "gce_subnetwork" {
  for_each = toset(var.availability_regions)
  
  project       = local.project.project_id 
  name          = "gce-vpc-subnet-${each.key}"  
  ip_cidr_range = element(var.gce_subnet_cidr_range, index(var.availability_regions, each.key))  
  region        = each.key  
  network       = local.vpc_network_id

  depends_on = [
    google_compute_network.vpc_network,
  ] 
}

#########################################################################
# Firewall Rules in vpc (only create if VPC doesn't exist)
#########################################################################

locals {
  gce_subnet_cidrs = [
    for i, region in var.availability_regions : 
    try(
      var.gce_subnet_cidr_range[i],
      var.gce_subnet_cidr_range[i % length(var.gce_subnet_cidr_range)]
    )
  ]

  all_internal_cidrs = local.gce_subnet_cidrs

  base_firewall_rules = [
    {
      name          = "${var.network_name}-fw-allow-lb-hc"
      description   = "Allow load balancer healthcheck for HTTP, NFS and Redis traffic"
      direction     = "INGRESS"
      source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
      allow = [{
        protocol = "tcp"
        ports    = ["80", "2049", "6379"]
      }]
      target_tags = [] 
    },
    {
      name          = "${var.network_name}-fw-allow-iap-ssh"
      description   = "Allow SSH connections via Identity-Aware Proxy (IAP)"
      direction     = "INGRESS"
      source_ranges = ["35.235.240.0/20"]
      allow = [{
        protocol = "tcp"
        ports    = ["22"]
      }]
      target_tags = []
    },
    {
      name          = "${var.network_name}-fw-allow-intra-vpc-tcp"
      description   = "Allow TCP traffic within the VPC network"
      direction     = "INGRESS"
      source_ranges = local.all_internal_cidrs
      allow = [{
        protocol = "tcp"
        ports    = [] 
      }]
      target_tags = [] 
    },
    {
      name          = "${var.network_name}-fw-allow-intra-vpc-udp"
      description   = "Allow UDP traffic within the VPC network"
      direction     = "INGRESS"
      source_ranges = local.all_internal_cidrs
      allow = [{
        protocol = "udp"
        ports    = [] 
      }]
      target_tags = [] 
    },
    {
      name          = "${var.network_name}-fw-allow-intra-vpc-icmp"
      description   = "Allow ICMP traffic within the VPC network"
      direction     = "INGRESS"
      source_ranges = local.all_internal_cidrs
      allow = [{
        protocol = "icmp"
        ports    = [] 
      }]
      target_tags = [] 
    }
  ]

  nfs_firewall_rules = [
    {
      name          = "${var.network_name}-fw-allow-nfs-tcp"
      description   = "Allow NFS service traffic on TCP protocol"
      direction     = "INGRESS"
      source_ranges = local.gce_subnet_cidrs
      target_tags   = ["nfsserver"]
      allow = [{
        protocol = "tcp"
        ports    = ["2049"]
      }]
    },
    {
      name          = "${var.network_name}-fw-allow-nfs-udp"
      description   = "Allow NFS service traffic on UDP protocol (for some NFS operations)"
      direction     = "INGRESS"
      source_ranges = local.gce_subnet_cidrs
      target_tags   = ["nfsserver"]
      allow = [{
        protocol = "udp"
        ports    = ["2049"]
      }]
    }
  ]

  http_firewall_rules = [
    {
      name          = "${var.network_name}-fw-allow-http-tcp"
      description   = "Allow HTTP and HTTPS service traffic on TCP protocol"
      direction     = "INGRESS"
      source_ranges = local.all_internal_cidrs
      target_tags   = ["httpserver", "webserver"]
      allow = [{
        protocol = "tcp"
        ports    = ["80", "443", "8080", "8443"]
      }]
    }
  ]

  custom_rules = concat(
    local.base_firewall_rules,
    local.nfs_firewall_rules,
    local.http_firewall_rules
  )

  firewall_rules_to_create = length(local.validation_errors) == 0 ? {
    for rule in local.custom_rules : rule.name => rule
  } : {}
}

locals {
  validation_errors = concat(
    length(var.gce_subnet_cidr_range) == 0 ? ["GCE subnet CIDR range cannot be empty"] : [],
    length(var.availability_regions) == 0 ? ["Availability regions cannot be empty"] : []
  )
}

resource "google_compute_firewall" "custom_rules" {
  for_each = length(local.validation_errors) == 0 ? {
    for idx, rule in local.custom_rules : rule.name => rule
  } : {}

  name    = each.value.name
  network = var.network_name
  project = local.project.project_id

  description   = each.value.description
  direction     = each.value.direction
  source_ranges = each.value.source_ranges
  target_tags   = each.value.target_tags

  dynamic "allow" {
    for_each = each.value.allow
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  depends_on = [
    google_compute_subnetwork.gce_subnetwork,
  ]
}

#########################################################################
# Creating Cloud NATs for Egress traffic from vpc (only if VPC doesn't exist)
#########################################################################

module "cloud_router" {  
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 7.0.0"
  name    = "${var.network_name}-nat-gw-${local.region}"
  project = local.project.project_id
  network = var.network_name
  region  = local.region

  bgp = {
    advertised_groups  = []
    asn = "64514"
  }

  nats = [{
    name = "${var.network_name}-nat-gw-${local.region}"
    source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  }]

  depends_on = [
    # module.firewall_rules,
    google_compute_firewall.custom_rules,
  ]
}

#########################################################################
# Enable Private Service Connect in VPC (only if VPC doesn't exist)
#########################################################################

resource "google_compute_global_address" "psconnect_private_ip_alloc" {  
  project       = local.project.project_id 
  name          = "${var.network_name}-psconnect-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network_name  

  depends_on = [
    module.cloud_router,
  ]

  lifecycle {
    prevent_destroy = false
  }
}
