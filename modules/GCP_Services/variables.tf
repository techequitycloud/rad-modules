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

# GROUP 1: Deployment 

variable "module_description" {
  description = "The description of the module. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = <<-EOT
**Purpose:** This module configures foundation Google Cloud platform services for all other modules. It prepares your Google Cloud project by configuring services required by other applications.

**What it does:**
- Sets up your Google Cloud project.
- Enables all the required services (APIs) that the other modules need to function.
- Provides an opportunity for you to select the services required by your application.

**Dependencies:** This module deploys into an existing Google Cloud project. It is a pre-requisite for other modules, and can support multiple module deployments.
EOT
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP Project"]
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP", "GKE", "Cloud SQL", "Compute Engine", "Cloud IAM", "Cloud Networking", "Config Management", "Policy Controller", "Cloud Service Mesh", "Security Posture Service"]
}

variable "credit" {
  description = "Specify the module cost {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 200
}

variable "require_credit_purchases" {
  description = "Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=104 }}"
  type        = bool
  default     = false
}

variable "deployment_id" {
  description = "Unique ID suffix for resources.  Leave blank to generate random ID."
  type        = string
  default     = null
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=1 order=102 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of trusted users with limited Google Cloud project admin privileges. (e.g. `username@abc.com`). {{UIMeta group=0 order=103 updatesafe }}"
  type        = list(string)
  default     = []
}

# GROUP 2: Application Project

variable "existing_project_id" {
  description = "Enter the project ID of the destination project. {{UIMeta group=2 order=200 updatesafe }}"
  type        = string
}

variable "enable_services" {
  description = "Enable project APIs. {{UIMeta group=0 order=202 updatesafe }}"
  type        = bool
  default     = true
}

# GROUP 3: Network

variable "network_name" {
  description = "Name to be assigned to the network. {{UIMeta group=0 order=301 updatesafe }}"
  type        = string
  default     = "vpc-network"
}

variable "availability_regions" {
  description = "The two regions where compute resources can be configured. The deployment might fail if sufficient resources not available in chosen region. {{UIMeta group=2 order=302 updatesafe }}"
  type        = list(string)
  default     = ["us-central1"]
}

variable "gce_subnet_cidr_range" {
  description = "List of GCE subnet CIDR blocks. {{UIMeta group=0 order=303 updatesafe }}"
  type = list(string)
  default = ["10.142.192.0/23", "10.142.190.0/23"]
}

variable "gke_subnet_cidr_range" {
  description = "List of GKE subnet CIDR blocks. {{UIMeta group=0 order=304 updatesafe }}"
  type = list(string)
  default = ["10.132.0.0/20", "10.128.0.0/20"]
}

variable "gke_pod_cidr_block" {
  description = "List of GKE pod CIDR blocks. {{UIMeta group=0 order=305 updatesafe }}"
  type = list(string)
  default = ["10.101.0.0/16", "10.100.0.0/16"]
}

variable "gke_service_cidr_block" {
  description = "List of GKE service CIDR blocks. {{UIMeta group=0 order=306 updatesafe }}"
  type = list(string)
  default = ["10.11.0.0/20", "10.10.0.0/20"]
}

# GROUP 4: SQL

variable "create_postgres" {
  description = "Select to create postgres database instance. {{UIMeta group=3 order=400 updatesafe }}"
  type        = bool
  default     = true  # Change to true to create the resource
}

variable "create_mysql" {
  description = "Select to create mysql database instance. {{UIMeta group=3 order=401 updatesafe }}"
  type        = bool
  default     = false  # Change to true to create the resource
}

variable "postgres_database_version" {
  description = "Database Server version to use. {{UIMeta group=0 order=402 options=POSTGRES_16 updatesafe }}"
  type        = string
  default     = "POSTGRES_16"
}

variable "postgres_database_availability_type" {
  description = "The availability type of the Cloud SQL instance. {{UIMeta group=0 order=403 options=REGIONAL,ZONAL updatesafe }}"
  type        = string
  default     = "ZONAL"
}

variable "postgres_tier" {
  description = "The machine type to use. Postgres supports only shared-core machine types, and custom machine types such as `db-custom-2-13312`. {{UIMeta group=0 order=404 updatesafe }}"
  type        = string
  default     = "db-custom-1-3840"
}

variable "mysql_database_version" {
  description = "Database Server version to use. {{UIMeta group=0 order=405 options=MYSQL_8_0 updatesafe }}"
  type        = string
  default     = "MYSQL_8_0"
}

variable "mysql_database_availability_type" {
  description = "The availability type of the Cloud SQL instance. {{UIMeta group=0 order=406 options=REGIONAL,ZONAL updatesafe }}"
  type        = string
  default     = "ZONAL"
}

variable "mysql_tier" {
  description = "The machine type to use. Postgres supports only shared-core machine types, and custom machine types such as `db-custom-2-13312`. {{UIMeta group=0 order=407 updatesafe }}"
  type        = string
  default     = "db-custom-1-3840"
}

# GROUP 6: NFS Service

variable "create_network_filesystem" {
  description = "Select to create NFS server using Compute Engine instances. {{UIMeta group=4 order=601 updatesafe}}"
  type        = bool
  default     = true
}

variable "network_filesystem_machine" {
  description = "NFS server machine type. {{UIMeta group=0 order=602 updatesafe }}"
  type        = string
  default     = "e2-small"
}

variable "network_filesystem_capacity" {
  description = "Size of NFS server disks. {{UIMeta group=0 order=603 updatesafe }}"
  type        = number
  default     = 10
}

# GROUP 14: GKE

variable "create_google_kubernetes_engine" {
  description = "Select to create GKE cluster {{UIMeta group=4 order=1401 updatesafe }}"
  type        = bool
  default     = false 
}

variable "google_kubernetes_engine_server" {
  description = "Name that will be assigned to the GKE cluster. {{UIMeta group=0 order=1402 updatesafe }}"
  type        = string
  default     = "gke-cluster"
}

variable "configure_config_management" {
  description = "Select to configure Config Management. GKE cluster is required. {{UIMeta group=0 order=1403 updatesafe }}"
  type        = bool
  default     = false
}

variable "configure_policy_controller" {
  description = "Select to configure policy controller. GKE cluster is required. {{UIMeta group=0 order=1404 updatesafe }}"
  type        = bool
  default     = false
}

variable "configure_cloud_service_mesh" {
  description = "Select to configure Cloud Service Mesh. GKE cluster is required. {{UIMeta group=0 order=1405 updatesafe }}"
  type        = bool
  default     = false
}

variable "configure_security_posture_service" {
  description = "Select to configure Security Posture Service. GKE cluster is required. {{UIMeta group=0 order=1406 updatesafe }}"
  type        = bool
  default     = false
}
