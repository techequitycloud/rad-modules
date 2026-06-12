#*
# * Copyright 2024 Google LLC
# *
# * Licensed under the Apache License, Version 2.0 (the "License");
# * you may not use this file except in compliance with the License.
# * You may obtain a copy of the License at
# *
# *      http://www.apache.org/licenses/LICENSE-2.0
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
#

# Debian 12 VMs that serve as MCDCv6 discovery scan targets.
# The migrationcenter user is created via startup script with SSH key
# authentication, matching the credentials configured in MCDCv6.
resource "google_compute_instance" "linux_vm" {
  count        = var.linux_vm_count
  project      = local.project.project_id
  name         = "${local.linux_vm_prefix}-${count.index + 1}"
  machine_type = var.linux_vm_machine_type
  zone         = var.zone

  tags = ["linux-target"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.linux_vm_boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = data.google_compute_network.lab_vpc.self_link
    access_config {}
  }

  # Creates the migrationcenter OS user and authorises the generated SSH public
  # key so MCDCv6 can authenticate during the discovery scan.
  metadata = {
    ssh-keys       = local.ssh_public_key_entry
    startup-script = <<-SCRIPT
      #!/bin/bash
      set -e
      id -u migrationcenter &>/dev/null || useradd -m -s /bin/bash migrationcenter
      install -d -m 700 -o migrationcenter -g migrationcenter /home/migrationcenter/.ssh
      echo '${tls_private_key.ssh_key.public_key_openssh}' \
        > /home/migrationcenter/.ssh/authorized_keys
      chmod 600 /home/migrationcenter/.ssh/authorized_keys
      chown migrationcenter:migrationcenter /home/migrationcenter/.ssh/authorized_keys
    SCRIPT
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_project_service.enabled_services,
    google_compute_network.lab_vpc,
  ]
}
