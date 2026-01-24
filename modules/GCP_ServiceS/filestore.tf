#
# Copyright 2021 Google LLC
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

# Resource definition for a Google Cloud Filestore instance.
resource "google_filestore_instance" "nfs_server" {
  count = var.create_filestore_nfs ? 1 : 0
  name  = "nfsserver"
  project = local.project.project_id
  location = data.google_compute_zones.available_zones.names[0]
  tier = "BASIC_HDD"

  file_shares {
    capacity_gb = 1024
    name        = "share"

    nfs_export_options {
      ip_ranges   = ["10.200.20.0/24"]
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }

  networks {
    network      = google_compute_network.vpc.name
    modes        = ["MODE_IPV4"]
    connect_mode = "DIRECT_PEERING"
  }
}
