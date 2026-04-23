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
# Data source — look up existing VPC when create_network = false
# ============================================

data "google_compute_network" "existing_vpc" {
  count   = var.create_network ? 0 : 1
  project = local.project.project_id
  name    = var.network_name
}

# ============================================
# Local — unified VPC reference regardless of create_network
# ============================================

locals {
  network = var.create_network ? google_compute_network.vpc[0] : data.google_compute_network.existing_vpc[0]
}

# ============================================
# VPC Network (only when create_network = true)
# ============================================

resource "google_compute_network" "vpc" {
  count                           = var.create_network ? 1 : 0
  project                         = local.project.project_id
  name                            = var.network_name
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = false
  mtu                             = 1500

  provisioner "local-exec" {
    when = destroy

    environment = {
      PROJECT_ID = self.project
    }

    command = <<-EOT
      #!/bin/bash
      set -e

      echo "Cleaning up resources blocking network deletion..."
      echo "Project ID: $PROJECT_ID"

      FIREWALLS=$(gcloud compute firewall-rules list \
        --project=$PROJECT_ID \
        --filter="name~^gke-.* AND name~.*-mcsd$" \
        --format="value(name)" 2>/dev/null || echo "")

      if [ -n "$FIREWALLS" ]; then
        for FW in $FIREWALLS; do
          gcloud compute firewall-rules delete $FW \
            --project=$PROJECT_ID \
            --quiet 2>/dev/null || true
        done
      fi

      ZONES=$(gcloud compute zones list --project=$PROJECT_ID --format="value(name)" 2>/dev/null || echo "")

      if [ -n "$ZONES" ]; then
        for ZONE in $ZONES; do
          NEGS=$(gcloud compute network-endpoint-groups list \
            --project=$PROJECT_ID \
            --zones=$ZONE \
            --filter="name~^gsmrsvd.*" \
            --format="value(name)" 2>/dev/null || echo "")

          if [ -n "$NEGS" ]; then
            for NEG in $NEGS; do
              gcloud compute network-endpoint-groups delete $NEG \
                --project=$PROJECT_ID \
                --zone=$ZONE \
                --quiet 2>/dev/null || true
            done
          fi
        done
      fi

      echo "Cleanup completed."
    EOT
  }
}

# ============================================
# Subnets (one per cluster — always managed, created within local.network)
# ============================================

resource "google_compute_subnetwork" "subnetwork" {
  for_each      = local.cluster_configs
  project       = local.project.project_id
  name          = "${var.subnet_name}-${each.key}"
  ip_cidr_range = each.value.ip_cidr_range
  region        = each.value.region
  network       = local.network.id

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
    data.google_compute_network.existing_vpc,
  ]
}

# ============================================
# Cloud Router (one per cluster/region)
# ============================================

resource "google_compute_router" "router" {
  for_each = local.cluster_configs
  project  = local.project.project_id
  name     = "router-${each.key}"
  region   = each.value.region
  network  = local.network.id

  bgp {
    asn = 64514
  }

  depends_on = [
    google_compute_network.vpc,
    data.google_compute_network.existing_vpc,
  ]
}

# ============================================
# Cloud NAT (one per router, targeting specific subnet)
# ============================================

resource "google_compute_router_nat" "nat_gateway" {
  for_each = local.cluster_configs
  project  = local.project.project_id
  name     = "nat-gateway-${each.key}"
  router   = google_compute_router.router[each.key].name
  region   = google_compute_router.router[each.key].region

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
# Static External IPs (one per cluster)
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

resource "google_compute_firewall" "allow_ssh" {
  project       = local.project.project_id
  name          = "allow-ssh"
  network       = local.network.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  depends_on = [
    google_compute_network.vpc,
    data.google_compute_network.existing_vpc,
  ]
}

resource "google_compute_firewall" "allow_internal" {
  project   = local.project.project_id
  name      = "allow-internal"
  network   = local.network.name
  direction = "INGRESS"
  priority  = 1000
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
    data.google_compute_network.existing_vpc,
  ]
}

resource "google_compute_firewall" "allow_gke_masters" {
  project       = local.project.project_id
  name          = "allow-gke-masters"
  network       = local.network.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["172.16.0.0/28"]

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
    data.google_compute_network.existing_vpc,
  ]
}

resource "google_compute_firewall" "allow_health_checks" {
  project   = local.project.project_id
  name      = "allow-health-checks"
  network   = local.network.name
  direction = "INGRESS"
  priority  = 1000
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22",
    "209.85.152.0/22",
    "209.85.204.0/22",
  ]

  allow {
    protocol = "tcp"
  }

  depends_on = [
    google_compute_network.vpc,
    data.google_compute_network.existing_vpc,
  ]
}

resource "google_compute_firewall" "allow_webhooks" {
  project       = local.project.project_id
  name          = "allow-webhooks"
  network       = local.network.name
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
    data.google_compute_network.existing_vpc,
  ]
}
