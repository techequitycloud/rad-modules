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

#########################################################################
# Service Account to connect to Cloud SQL
#########################################################################

# Assign the Storage Admin role to the NFS server service account
resource "google_project_iam_member" "nfs_server_storage_admin" {
  count   = var.create_network_filesystem ? 1 : 0              # Create only if create_network_filesystem is true
  project = local.project.project_id            # The project ID where the IAM role will be assigned
  role    = "roles/storage.admin"               # The role to be assigned
  member  = "serviceAccount:${google_service_account.nfs_server_sa_admin.email}"  # Use count.index
  
  # Ensures that this IAM role assignment depends on the creation of the service account
  depends_on = [
    google_service_account.nfs_server_sa_admin,
  ]
}

#########################################################################
# Reserve static IP
#########################################################################
# Allocate a static internal IP address for NFS server
resource "google_compute_address" "static_internal_ip" {
  count      = var.create_network_filesystem ? 1 : 0  # Create only if create_network_filesystem is true
  project    = local.project.project_id                  # Reference to the project ID from local variables
  region     = local.region                               # Region where the IP will be allocated
  name       = "nfsserver-static-ip"                     # Name for the static IP resource
  subnetwork = google_compute_subnetwork.gce_subnetwork[local.region].id  # Reference the created subnetwork directly
  address_type = "INTERNAL"                              # Specify that the IP is for internal use
  purpose    = "GCE_ENDPOINT"                            # Purpose for the static IP

  depends_on = [
    google_service_networking_connection.psconnect,
    time_sleep.wait_120_seconds,
  ]
}

#########################################################################
# Creating GCE VMs in VPC
#########################################################################

# Define an instance template for NFS server VMs
resource "google_compute_instance_template" "nfs_server" {
  count                     = var.create_network_filesystem ? 1 : 0  # Create only if create_network_filesystem is true
  project                   = local.project.project_id                  # Reference to the project ID from local variables
  region                    = local.region                              # Region for the instance template
  name                      = "nfsserver-tpl"                           # Name of the instance template
  machine_type              = var.network_filesystem_machine                           # Machine type for the VM
  metadata_startup_script   = file("${path.module}/scripts/nfs/create_nfs.sh") # Startup script from a file
  tags                      = ["nfsserver"]

  # Metadata to enable OS Login feature
  metadata = {
    enable-oslogin = true
  }

  # Boot disk configuration using an Ubuntu image
  disk {
    boot         = true
    source_image = "ubuntu-os-cloud/ubuntu-2204-jammy-v20240927"
    disk_type    = "pd-standard"
    disk_size_gb = 10
  }

  # Additional disk configuration for data storage
  disk {
    boot         = false
    disk_type    = "pd-ssd"
    disk_size_gb = var.network_filesystem_capacity
    device_name  = "data-disk"
    auto_delete  = false
    resource_policies = [google_compute_resource_policy.daily_snapshot[count.index].id]  # Use count.index
  }

  # Network interface configuration using a static IP and subnetwork
  network_interface {
    subnetwork          = "https://www.googleapis.com/compute/v1/projects/${var.existing_project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"  # Subnet ID for private IP connectivity
    subnetwork_project  = var.existing_project_id
    network_ip          = google_compute_address.static_internal_ip[0].address  # Use count.index
  }

  # Associate the VM with the NFS Server service account and grant cloud platform scope permissions
  service_account {
    email  = google_service_account.nfs_server_sa_admin.email  # Use count.index
    scopes = ["cloud-platform"]
  }

  # Ensure that the instance template creation waits for specific resources
  depends_on = [
    time_sleep.wait_120_seconds,
    google_compute_resource_policy.daily_snapshot,
    google_compute_address.static_internal_ip,
    google_project_iam_member.nfs_server_storage_admin,
    google_service_account.nfs_server_sa_admin,
  ]
}

#########################################################################
# Managed Instance Group
#########################################################################

# Define a managed instance group for NFS servers
resource "google_compute_instance_group_manager" "nfs_server" {
  count               = var.create_network_filesystem ? 1 : 0  # Create only if create_network_filesystem is true
  project             = local.project.project_id               # Reference to the project ID from local variables
  name                = "nfsserver-mig"                        # Name of the managed instance group
  zone                = data.google_compute_zones.available_zones.names[0] # Zone for the MIG
  base_instance_name  = "nfsserver"                            # Base name for instances in the group
  target_size         = 1                                      # Number of instances in the group

  # Version configuration for the instance template to use
  version {
    name              = "v1"
    instance_template = google_compute_instance_template.nfs_server[count.index].id  # Use count.index
  }

  # Stateful disk configuration to ensure that the data disk persists
  stateful_disk {
    device_name   = "data-disk"
    delete_rule   = "ON_PERMANENT_INSTANCE_DELETION"
  }
  
  # Configuration for named ports that the instance group will expose
  named_port {
    name = "nfs"      # Name for the NFS service port
    port = 2049       # Port number for NFS service
  }

  named_port {
    name = "rpcbind"  # Name for the RPC bind service port
    port = 111        # Port number for RPC bind service
  }

  # Auto-healing policies to automatically recreate unhealthy instances
  auto_healing_policies {
    health_check      = google_compute_health_check.nfs_server_health_check[count.index].id  # Use count.index
    initial_delay_sec = 300        # Time to wait before considering an instance unhealthy
  }

  # Update policy configuration for handling updates to the instance group
  update_policy {
    type                  = "PROACTIVE"            # Update type is proactive
    minimal_action        = "REPLACE"              # Minimal action is to replace instances
    replacement_method    = "RECREATE"             # Method of replacement is recreation of instances
    max_surge_fixed       = 0                      # No additional instances during update
    max_unavailable_fixed = 1                      # One instance can be unavailable during update
  }

  # Lifecycle rule to create new resources before destroying the old ones
  lifecycle {
    create_before_destroy = true   # Helps in zero-downtime updates and rollbacks
  }

  depends_on = [
    google_compute_health_check.nfs_server_health_check,
  ]
}

#########################################################################
# Health Check
#########################################################################

# Define a health check for NFS servers
resource "google_compute_health_check" "nfs_server_health_check" {
  count = var.create_network_filesystem ? 1 : 0  # Create only if create_network_filesystem is true
  project             = local.project.project_id          # Reference to the project ID from local variables
  name                = "nfsserver-health-check"          # Name of the health check
  check_interval_sec  = 30                                # Time between health checks
  timeout_sec         = 10                                # Timeout for each health check response
  healthy_threshold   = 2                                 # Number of successful checks to consider healthy
  unhealthy_threshold = 3                                 # Number of failed checks to consider unhealthy

  # TCP health check configuration
  tcp_health_check {
    port = 2049 # Standard port for NFS service
  }

  depends_on = [
    google_compute_instance_template.nfs_server,
  ]
}

#########################################################################
# Snapshot Schedule for Data Disk
#########################################################################

# Create a resource policy for daily snapshots of the data disk
resource "google_compute_resource_policy" "daily_snapshot" {
  count = var.create_network_filesystem ? 1 : 0  # Create only if create_network_filesystem is true
  project = local.project.project_id                     # Reference to the project ID from local variables
  name    = "daily-data-disk-snapshot-policy"            # Name of the snapshot policy
  region  = local.region                                 # Region where the policy will be applied

  # Configuration for the snapshot schedule policy
  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1                                # Interval of the schedule (every day)
        start_time    = "00:00"                          # Time of day when the snapshot is created
      }
    }

    # Retention policy for the snapshots
    retention_policy {
      max_retention_days    = 7                          # Maximum number of days to retain a snapshot
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"      # Policy when the source disk is deleted
    }
  }

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    google_service_networking_connection.psconnect,
    time_sleep.wait_120_seconds,
  ]
}

#########################################################################
# Time Sleep to Introduce a Delay
#########################################################################

resource "time_sleep" "wait_30_seconds" {
  count = var.create_network_filesystem ? 1 : 0 
  create_duration = "30s" 
  
  depends_on = [
    google_compute_instance_group_manager.nfs_server,
  ]
}