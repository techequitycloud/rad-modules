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
  project                         = local.project.project_id
  name                            = var.network_name
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = false
  mtu                             = 1500

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "🔍 Cleaning up resources blocking network deletion..."
      
      # Clean up GKE firewall rules (starting with 'gke' and ending with 'mcsd')
      echo "🔍 Searching for GKE firewall rules (gke-*-mcsd)..."
      FIREWALLS=$(gcloud compute firewall-rules list \
        --project=${local.project.project_id} \
        --filter="name~^gke-.* AND name~.*-mcsd$" \
        --format="value(name)" 2>/dev/null || echo "")
      
      if [ -n "$FIREWALLS" ]; then
        echo "🔥 Found GKE firewall rules:"
        for FW in $FIREWALLS; do
          echo "  🗑️  Deleting firewall rule: $FW"
          gcloud compute firewall-rules delete $FW \
            --project=${local.project.project_id} \
            --quiet 2>/dev/null || echo "  ⚠️  Failed to delete $FW (may already be deleted)"
        done
      else
        echo "✅ No GKE firewall rules found"
      fi
      
      # Clean up NEGs starting with 'gsmrsvd'
      echo "🔍 Searching for NEGs starting with 'gsmrsvd'..."
      
      ZONES=$(gcloud compute zones list --project=${local.project.project_id} --format="value(name)" 2>/dev/null || echo "")
      
      if [ -z "$ZONES" ]; then
        echo "⚠️  Could not retrieve zones, skipping NEG cleanup"
      else
        NEG_FOUND=false
        for ZONE in $ZONES; do
          NEGS=$(gcloud compute network-endpoint-groups list \
            --project=${local.project.project_id} \
            --zones=$ZONE \
            --filter="name~^gsmrsvd.*" \
            --format="value(name)" 2>/dev/null || echo "")
          
          if [ -n "$NEGS" ]; then
            NEG_FOUND=true
            echo "📍 Found NEGs in zone $ZONE:"
            for NEG in $NEGS; do
              echo "  🗑️  Deleting NEG: $NEG"
              gcloud compute network-endpoint-groups delete $NEG \
                --project=${local.project.project_id} \
                --zone=$ZONE \
                --quiet 2>/dev/null || echo "  ⚠️  Failed to delete $NEG (may already be deleted)"
            done
          fi
        done
        
        if [ "$NEG_FOUND" = false ]; then
          echo "✅ No NEGs found"
        fi
      fi
      
      echo "✅ Cleanup completed, network should now be deletable"
    EOT
  }
}

# Subnet resource - NO dependency on cleanup resource
resource "google_compute_subnetwork" "subnetwork" {
  project                  = local.project.project_id
  name                     = var.subnet_name
  ip_cidr_range            = tolist(var.ip_cidr_ranges)[0]
  region                   = var.gcp_region
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

# Firewall rule to allow all traffic within the VPC network
resource "google_compute_firewall" "fw_allow_intra_vpc" {
  project = local.project.project_id
  name    = "fw-allow-intra-vpc"
  network = google_compute_network.vpc.name

  allow {
    protocol = "all"
  }

  source_ranges = [var.pod_cidr_block]
  depends_on    = [google_compute_network.vpc]
}

# Firewall rule to allow NFS service traffic on TCP protocol
resource "google_compute_firewall" "fw_allow_gce_nfs_tcp" {
  project = local.project.project_id
  name    = "fw-allow-nfs-tcp"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["2049"]
  }

  source_ranges = tolist(var.ip_cidr_ranges)
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

  source_ranges = tolist(var.ip_cidr_ranges)
  target_tags   = ["http-server"]
  depends_on    = [google_compute_network.vpc]
}

#########################################################################
# Creating Cloud NATs for Egress traffic from vpc
#########################################################################

# Define a Google Compute Router resource for the region
resource "google_compute_router" "cr_region" {
  project = local.project.project_id
  name    = "cr1-${var.gcp_region}"
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
  name                               = "nat-gw1-${var.gcp_region}"
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
