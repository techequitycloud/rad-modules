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

# ============================================
# VPC Network
# ============================================
resource "google_compute_network" "vpc" {
  project                         = local.project.project_id
  name                            = var.network_name
  auto_create_subnetworks         = false
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

# ============================================
# Subnets (One per cluster)
# ============================================
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

  depends_on = [
    google_compute_network.vpc,
  ]
}

# ============================================
# Cloud Router (One per cluster/region)
# ============================================
resource "google_compute_router" "router" {
  for_each = local.cluster_configs
  project  = local.project.project_id
  name     = "router-${each.key}"
  region   = each.value.region
  network  = google_compute_network.vpc.id
  
  bgp {
    asn = 64514
  }

  depends_on = [
    google_compute_network.vpc,
  ]
}

# ============================================
# Cloud NAT (One per router, targeting specific subnet)
# ============================================
resource "google_compute_router_nat" "nat_gateway" {
  for_each = local.cluster_configs
  project  = local.project.project_id
  name     = "nat-gateway-${each.key}"
  router   = google_compute_router.router[each.key].name
  region   = google_compute_router.router[each.key].region

  # Use LIST_OF_SUBNETWORKS to avoid conflicts
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.subnetwork[each.key].id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  depends_on = [
    google_compute_router.router,
    google_compute_subnetwork.subnetwork,
  ]
}

# ============================================
# Static External IPs (One per cluster)
# ============================================
resource "google_compute_address" "static_ip" {
  for_each     = local.cluster_configs
  project      = local.project.project_id
  name         = "static-ip-${each.key}"
  region       = each.value.region
  address_type = "EXTERNAL"
}

# ============================================
# Firewall Rules
# ============================================

# Allow SSH access
resource "google_compute_firewall" "allow_ssh" {
  project       = local.project.project_id
  name          = "allow-ssh"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  depends_on = [
    google_compute_network.vpc,
  ]
}

# Allow internal communication between subnets
resource "google_compute_firewall" "allow_internal" {
  project       = local.project.project_id
  name          = "allow-internal"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = concat(
    [for config in local.cluster_configs : config.ip_cidr_range],
    [for config in local.cluster_configs : config.pod_cidr_block],
    [for config in local.cluster_configs : config.service_cidr_block]
  )

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

  depends_on = [
    google_compute_network.vpc,
  ]
}

# Allow GKE control plane to communicate with nodes
resource "google_compute_firewall" "allow_gke_masters" {
  project       = local.project.project_id
  name          = "allow-gke-masters"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["172.16.0.0/28"] # GKE control plane default range

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  depends_on = [
    google_compute_network.vpc,
  ]
}

# Allow Google Cloud health checks
resource "google_compute_firewall" "allow_health_checks" {
  project       = local.project.project_id
  name          = "allow-health-checks"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [
    "35.191.0.0/16",    # Google Cloud health checkers
    "130.211.0.0/22",   # Google Cloud health checkers
    "209.85.152.0/22",  # Google Cloud health checkers
    "209.85.204.0/22"   # Google Cloud health checkers
  ]

  allow {
    protocol = "tcp"
  }

  depends_on = [
    google_compute_network.vpc,
  ]
}

# Allow webhook admission controllers (required for ASM/Istio)
resource "google_compute_firewall" "allow_webhooks" {
  project       = local.project.project_id
  name          = "allow-webhooks"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [for config in local.cluster_configs : config.ip_cidr_range]

  allow {
    protocol = "tcp"
    ports    = ["443", "8443", "9443", "15017"]
  }

  target_tags = ["gke-node"]

  depends_on = [
    google_compute_network.vpc,
  ]
}
