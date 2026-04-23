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
# Data sources — look up existing network/subnet when create_network = false
#########################################################################

data "google_compute_network" "existing_vpc" {
  count   = var.create_network ? 0 : 1
  project = local.project.project_id
  name    = var.network_name
}

data "google_compute_subnetwork" "existing_subnet" {
  count   = var.create_network ? 0 : 1
  project = local.project.project_id
  name    = var.subnet_name
  region  = var.gcp_region
}

#########################################################################
# Locals — unified references regardless of create_network
#########################################################################

locals {
  network = var.create_network ? google_compute_network.vpc[0] : data.google_compute_network.existing_vpc[0]
  subnet  = var.create_network ? google_compute_subnetwork.subnetwork[0] : data.google_compute_subnetwork.existing_subnet[0]
}

#########################################################################
# vpc - VPC Network & Subnets (only when create_network = true)
#########################################################################

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

resource "google_compute_subnetwork" "subnetwork" {
  count                    = var.create_network ? 1 : 0
  project                  = local.project.project_id
  name                     = var.subnet_name
  ip_cidr_range            = tolist(var.ip_cidr_ranges)[0]
  region                   = var.gcp_region
  network                  = google_compute_network.vpc[0].name
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
# Firewall Rules (only when create_network = true)
#########################################################################

resource "google_compute_firewall" "fw_allow_lb_hc" {
  count   = var.create_network ? 1 : 0
  project = local.project.project_id
  name    = "fw-allow-lb-hc"
  network = google_compute_network.vpc[0].name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  depends_on    = [google_compute_network.vpc]
}

resource "google_compute_firewall" "fw_allow_nfs_hc" {
  count   = var.create_network ? 1 : 0
  project = local.project.project_id
  name    = "fw-allow-nfs-hc"
  network = google_compute_network.vpc[0].name

  allow {
    protocol = "tcp"
    ports    = ["2049"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  depends_on    = [google_compute_network.vpc]
}

resource "google_compute_firewall" "fw_allow_iap_ssh" {
  count   = var.create_network ? 1 : 0
  project = local.project.project_id
  name    = "fw-allow-iap-ssh"
  network = google_compute_network.vpc[0].name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  depends_on    = [google_compute_network.vpc]
}

resource "google_compute_firewall" "fw_allow_intra_vpc" {
  count   = var.create_network ? 1 : 0
  project = local.project.project_id
  name    = "fw-allow-intra-vpc"
  network = google_compute_network.vpc[0].name

  allow {
    protocol = "all"
  }

  source_ranges = [var.pod_cidr_block]
  depends_on    = [google_compute_network.vpc]
}

resource "google_compute_firewall" "fw_allow_gce_nfs_tcp" {
  count   = var.create_network ? 1 : 0
  project = local.project.project_id
  name    = "fw-allow-nfs-tcp"
  network = google_compute_network.vpc[0].name

  allow {
    protocol = "tcp"
    ports    = ["2049"]
  }

  source_ranges = tolist(var.ip_cidr_ranges)
  target_tags   = ["nfs-server"]
  depends_on    = [google_compute_network.vpc]
}

resource "google_compute_firewall" "fw_allow_http_tcp" {
  count   = var.create_network ? 1 : 0
  project = local.project.project_id
  name    = "fw-allow-http-tcp"
  network = google_compute_network.vpc[0].name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = tolist(var.ip_cidr_ranges)
  target_tags   = ["http-server"]
  depends_on    = [google_compute_network.vpc]
}

#########################################################################
# Cloud Router & NAT (only when create_network = true)
#########################################################################

resource "google_compute_router" "cr_region" {
  count   = var.create_network ? 1 : 0
  project = local.project.project_id
  name    = "cr1-${var.gcp_region}"
  region  = google_compute_subnetwork.subnetwork[0].region
  network = google_compute_network.vpc[0].id

  bgp {
    asn = 64514
  }

  depends_on = [google_compute_network.vpc]
}

resource "google_compute_router_nat" "nat_gw_region" {
  count                              = var.create_network ? 1 : 0
  project                            = local.project.project_id
  name                               = "nat-gw1-${var.gcp_region}"
  router                             = google_compute_router.cr_region[0].name
  region                             = google_compute_router.cr_region[0].region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  depends_on = [google_compute_network.vpc]
}
