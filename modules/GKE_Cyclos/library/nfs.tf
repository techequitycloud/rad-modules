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
  count   = var.create_network_filesystem ? 1 : 0              
  project = local.project.project_id            
  role    = "roles/storage.admin"               
  member  = "serviceAccount:${google_service_account.nfs_server_sa_admin.email}"  
  
  depends_on = [
    google_service_account.nfs_server_sa_admin,
  ]
}

#########################################################################
# Reserve static IP
#########################################################################
# Allocate a static internal IP address for NFS server
resource "google_compute_address" "static_internal_ip" {
  count      = var.create_network_filesystem ? 1 : 0  
  project    = local.project.project_id                  
  region     = local.region                               
  name       = "nfsserver-static-ip"                     
  subnetwork = google_compute_subnetwork.gce_subnetwork[local.region].id  
  address_type = "INTERNAL"                              
  purpose    = "GCE_ENDPOINT"                            

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
  count                     = var.create_network_filesystem ? 1 : 0  
  project                   = local.project.project_id                  
  region                    = local.region                              
  name                      = "nfsserver-tpl"                           
  machine_type              = var.network_filesystem_machine                           
  metadata_startup_script   = file("${path.module}/scripts/nfs/create_nfs.sh") 
  tags                      = ["nfsserver"]

  metadata = {
    enable-oslogin = true
  }

  disk {
    boot         = true
    source_image = "ubuntu-os-cloud/ubuntu-2204-jammy-v20240927"
    disk_type    = "pd-standard"
    disk_size_gb = 10
  }

  disk {
    boot         = false
    disk_type    = "pd-ssd"
    disk_size_gb = var.network_filesystem_capacity
    device_name  = "data-disk"
    auto_delete  = false
    resource_policies = [google_compute_resource_policy.daily_snapshot[count.index].id]  
  }

  network_interface {
    subnetwork          = "https://www.googleapis.com/compute/v1/projects/${var.existing_project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"  # Subnet ID for private IP connectivity
    subnetwork_project  = var.existing_project_id
    network_ip          = google_compute_address.static_internal_ip[0].address  
  }

  service_account {
    email  = google_service_account.nfs_server_sa_admin.email  
    scopes = ["cloud-platform"]
  }

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
  count               = var.create_network_filesystem ? 1 : 0  
  project             = local.project.project_id               
  name                = "nfsserver-mig"                        
  zone                = data.google_compute_zones.available_zones.names[0] 
  base_instance_name  = "nfsserver"                            
  target_size         = 1                                      

  version {
    name              = "v1"
    instance_template = google_compute_instance_template.nfs_server[count.index].id  
  }

  stateful_disk {
    device_name   = "data-disk"
    delete_rule   = "ON_PERMANENT_INSTANCE_DELETION"
  }
  
  named_port {
    name = "nfs"      
    port = 2049      
  }

  named_port {
    name = "rpcbind"  
    port = 111        
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.nfs_server_health_check[count.index].id  
    initial_delay_sec = 300        
  }

  update_policy {
    type                  = "PROACTIVE"            
    minimal_action        = "REPLACE"              
    replacement_method    = "RECREATE"             
    max_surge_fixed       = 0                     
    max_unavailable_fixed = 1                      
  }

  lifecycle {
    create_before_destroy = true   
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
  count = var.create_network_filesystem ? 1 : 0  
  project             = local.project.project_id          
  name                = "nfsserver-health-check"          
  check_interval_sec  = 30                                
  timeout_sec         = 10                                
  healthy_threshold   = 2                                 
  unhealthy_threshold = 3                                 

  tcp_health_check {
    port = 2049 
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
  count = var.create_network_filesystem ? 1 : 0  
  project = local.project.project_id                     
  name    = "daily-data-disk-snapshot-policy"            
  region  = local.region                                 

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1                               
        start_time    = "00:00"                         
      }
    }

    # Retention policy for the snapshots
    retention_policy {
      max_retention_days    = 7                          
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"      
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