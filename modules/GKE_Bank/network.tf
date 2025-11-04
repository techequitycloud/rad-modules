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
  name                     = "vpc-subnet"
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
# Cleanup GKE-created Firewall Rules (Destroy-time)
#########################################################################

# This resource ensures all GKE-created firewall rules are deleted before VPC deletion
resource "null_resource" "cleanup_gke_firewall_rules" {
  triggers = {
    project_id   = local.project.project_id
    network_name = var.network_name
    # Trigger on VPC ID to ensure it runs when VPC is destroyed
    vpc_id       = google_compute_network.vpc.id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "============================================"
      echo "Cleaning up GKE-created firewall rules"
      echo "============================================"
      
      PROJECT_ID="${self.triggers.project_id}"
      NETWORK_NAME="${self.triggers.network_name}"
      
      echo "Project: $PROJECT_ID"
      echo "Network: $NETWORK_NAME"
      echo ""
      
      # Get all firewall rules for this network
      echo "Fetching firewall rules for network: $NETWORK_NAME"
      
      # List all GKE-created firewall rules (k8s-fw-*, gke-*, k8s-*)
      gke_firewalls=$(gcloud compute firewall-rules list \
        --project="$PROJECT_ID" \
        --filter="network:$NETWORK_NAME AND (name~'^k8s-fw-' OR name~'^gke-' OR name~'^k8s-')" \
        --format="value(name)" 2>/dev/null || echo "")
      
      if [ -z "$gke_firewalls" ]; then
        echo "✓ No GKE-created firewall rules found"
      else
        echo "Found GKE-created firewall rules:"
        echo "$gke_firewalls"
        echo ""
        
        # Delete each firewall rule
        echo "Deleting firewall rules..."
        echo "$gke_firewalls" | while read -r fw_name; do
          if [ -n "$fw_name" ]; then
            echo "  → Deleting: $fw_name"
            gcloud compute firewall-rules delete "$fw_name" \
              --project="$PROJECT_ID" \
              --quiet 2>/dev/null || {
              echo "    ⚠ Failed to delete $fw_name (may already be deleted)"
            }
          fi
        done
        
        echo ""
        echo "✓ GKE firewall rules cleanup complete"
      fi
      
      # Additional cleanup: Delete any remaining firewall rules on this network
      echo ""
      echo "Checking for any remaining firewall rules..."
      
      remaining_firewalls=$(gcloud compute firewall-rules list \
        --project="$PROJECT_ID" \
        --filter="network:$NETWORK_NAME" \
        --format="value(name)" 2>/dev/null || echo "")
      
      if [ -n "$remaining_firewalls" ]; then
        echo "Found remaining firewall rules (likely Terraform-managed):"
        echo "$remaining_firewalls"
        echo ""
        echo "Note: Terraform-managed rules will be deleted by Terraform"
      else
        echo "✓ No remaining firewall rules found"
      fi
      
      echo ""
      echo "============================================"
      echo "Firewall cleanup complete"
      echo "============================================"
    EOT
    
    interpreter = ["/bin/bash", "-c"]
    on_failure  = continue
  }

  # The cleanup resource depends on VPC existing (for creation)
  # But during destruction, it will run BEFORE VPC is destroyed
  depends_on = [
    google_compute_network.vpc,
  ]
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
