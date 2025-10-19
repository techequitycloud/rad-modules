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
# Local variables for NFS infrastructure existence checks
#########################################################################

# Random suffix for new NFS resources to avoid naming conflicts
resource "random_string" "nfs_suffix" {
  count   = var.create_network_filesystem ? 1 : 0  
  length  = 4
  special = false
  upper   = false
}

#########################################################################
# Reserve static IP
#########################################################################
# Allocate a static internal IP address for NFS server
resource "google_compute_address" "static_internal_ip" {
  count        = var.create_network_filesystem ? 1 : 0  
  project      = local.project.project_id                  
  region       = local.region                               
  name         = "nfsserver-static-ip"                     
  subnetwork   = local.gce_subnet_id
  address_type = "INTERNAL"                              
  purpose      = "GCE_ENDPOINT"                            

  depends_on = [
    google_service_networking_connection.psconnect,
    time_sleep.wait_240_seconds,
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
  name                      = "nfsserver-tpl-${random_string.nfs_suffix[0].result}"                           
  machine_type              = var.network_filesystem_machine                           
  metadata_startup_script   = file("${path.module}/scripts/create_nfs.sh") 
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
    resource_policies = [google_compute_resource_policy.daily_snapshot[0].id]  
  }

  network_interface {
    subnetwork          = "https://www.googleapis.com/compute/v1/projects/${var.existing_project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"  # Subnet ID for private IP connectivity
    subnetwork_project  = var.existing_project_id
    network_ip          = google_compute_address.static_internal_ip[0].address  
  }

  service_account {
    email = local.nfsserver_sa_email
    scopes = ["cloud-platform"]
  }

  depends_on = [
    time_sleep.wait_240_seconds,
    google_compute_resource_policy.daily_snapshot,
    google_compute_address.static_internal_ip,
    google_service_account.nfs_server_sa_admin,
    random_string.nfs_suffix,
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
    instance_template = google_compute_instance_template.nfs_server[0].id  
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
    health_check      = google_compute_health_check.nfs_server_health_check[0].id  
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
    google_service_networking_connection.psconnect,
    google_compute_health_check.nfs_server_health_check,
    google_compute_instance_template.nfs_server,
  ]
}

#########################################################################
# Health Check
#########################################################################

# Define a health check for NFS servers
resource "google_compute_health_check" "nfs_server_health_check" {
  count               = var.create_network_filesystem ? 1 : 0  
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
  count   = var.create_network_filesystem ? 1 : 0  
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
    time_sleep.wait_240_seconds,
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

#########################################################################
# Data sources to get instance details after creation (for new instances)
#########################################################################

# Get the instance group for newly created manager
data "google_compute_instance_group" "nfs_server_group" {
  count   = var.create_network_filesystem && length(google_compute_instance_group_manager.nfs_server) > 0 ? 1 : 0
  name    = regex("instanceGroups/(.+)$", google_compute_instance_group_manager.nfs_server[0].instance_group)[0]
  zone    = google_compute_instance_group_manager.nfs_server[0].zone
  project = local.project.project_id
  
  depends_on = [
    time_sleep.wait_30_seconds
  ]
}
