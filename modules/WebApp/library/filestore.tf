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

locals {
  filestore_instance = format("filestore-db-%s", local.random_id)
}

resource "google_filestore_instance" "instance" {
  count    = var.create_filestore ? 1 : 0
  project  = local.project.project_id
  name     = local.filestore_instance
  location = "${local.region}-b"
  tier     = var.filestore_tier

  file_shares {
    capacity_gb = var.filestore_capacity
    name        = "share"

    nfs_export_options {
      ip_ranges = flatten([
        for region in var.availability_regions : [
          element(var.gce_subnet_cidr_range, index(var.availability_regions, region)),
          element(var.gke_subnet_cidr_range, index(var.availability_regions, region))
        ]
      ])
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }

  networks {
    network      = "https://www.googleapis.com/compute/v1/projects/${local.configuration[var.project_environment].host_project_id}/global/networks/${var.network_name}"
    modes        = ["MODE_IPV4"]
    connect_mode = "DIRECT_PEERING"
  }

  depends_on = [
    module.vpc,
    module.foundation_platform,
    google_project_service.enabled_services,
  ]
}

resource "google_filestore_backup" "backup" {
  count             = var.create_filestore ? 1 : 0
  name              = local.filestore_instance
  project           = local.project.project_id
  location          = "${local.region}"
  description       = "Filestore instance backup"
  source_instance   = google_filestore_instance.instance[count.index].id
  source_file_share = "share"

  depends_on = [
    google_filestore_instance.instance,
  ]
}
