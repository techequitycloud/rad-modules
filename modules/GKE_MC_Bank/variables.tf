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

locals {
  available_regions = ["us-west1", "us-east1", "europe-west1", "asia-northeast1"]
  cluster_configs = {
    for i in range(var.cluster_size) : "cluster${i + 1}" => {
      gke_cluster_name   = "gke-cluster-${i + 1}"
      region             = local.available_regions[i]
      ip_cidr_range      = cidrsubnet("10.0.0.0/8", 8, i)
      pod_ip_range       = "pod-ip-range-${i + 1}"
      pod_cidr_block     = cidrsubnet(cidrsubnet("10.0.0.0/8", 8, i), 8, 0)
      service_ip_range   = "service-ip-range-${i + 1}"
      service_cidr_block = cidrsubnet(cidrsubnet("10.0.0.0/8", 8, i), 8, 1)
    }
  }
}

// GROUP 1: Provider 

variable "module_description" {
  description = "The description of the module. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = <<-EOT
**Purpose:** This module deploys an advanced, microservice banking demo application on Google Kubernetes Engine (GKE). It is a reference implementation for financial institutions that need a highly scalable, secure, and feature-rich platform for their banking applications.

**What it does:**
- Deploys a microservices-based banking application on GKE across multiple clusters.
- Utilizes advanced Cloud Service Mesh for enhanced security and multi-cluster management.
- Provides a centralized dashboard for managing banking services across multiple clusters.

**Dependencies:** This module deploys into an existing Google Cloud project. We recommend using the Google Cloud project exclusively for this deployment. NB: You may encounter challenges deleting this module due to retained Cloud Service Mesh configurations. 
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
  default     = ["GCP", "GKE", "Anthos Service Mesh", "Cloud IAM", "Cloud Networking"]
}

variable "credit_cost" {
  description = "Specify the module cost {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 150
}

variable "require_credit_purchases" {
  description = "Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=104 }}"
  type        = bool
  default     = false
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=1 order=102 updatesafe }}"
  type        = string
  default     = ""
}

variable "trusted_users" {
  description = "List of trusted users (e.g. `username@abc.com`). {{UIMeta group=0 order=103 updatesafe }}"
  type        = list(string)
  default     = []
}

variable "deployment_id" {
  description = "Unique ID suffix for resources.  Leave blank to generate random ID."
  type        = string
  default     = null
}

// GROUP 2: Main

variable "existing_project_id" {
  description = "Enter the project ID of the destination project. {{UIMeta group=2 order=200 updatesafe }}"
  type        = string
}

variable "cluster_size" {
  description = "The number of GKE clusters to create."
  type        = number
  default     = 2
}

// GROUP 4: Main

variable "enable_services" {
  description = "Enable project APIs.  When using an existing project, this is set to false. {{UIMeta group=0 order=401 }}"
  type        = bool
  default     = true
}

variable "domain" {
  description = "The domain name to use for the application."
  type        = string
  default     = "example.com"
}

variable "enable_cloud_service_mesh" {
  description = "Enable Cloud Service Mesh. {{UIMeta group=0 order=402 }}"
  type        = bool
  default     = true
}

variable "cloud_service_mesh_version" {
  description = "Cloud Service Mesh version. {{UIMeta group=0 order=403 }}"
  type        = string
  default     = "1.23.4-asm.1"
}

variable "enable_config_management" {
  description = "Enable Config Management. {{UIMeta group=0 order=404 }}"
  type        = bool
  default     = false
}

variable "config_management_version" {
  description = "Anthos Config Management version. {{UIMeta group=0 order=405 }}"
  type        = string
  default     = "1.22.0"
}

variable "config_sync_repo" {
  description = "The URL of the Git repository for Config Sync. {{UIMeta group=0 order=406 }}"
  type        = string
  default     = "https://github.com/GoogleCloudPlatform/anthos-config-management-samples"
}

variable "config_sync_policy_dir" {
  description = "The directory within the Git repository for Config Sync. {{UIMeta group=0 order=407 }}"
  type        = string
  default     = "config-sync-quickstart/multirepo/root"
}

// GROUP 5: Network

variable "enable_monitoring" {
  description = "Enable Cloud monitoring. {{UIMeta group=0 order=501 }}"
  type        = bool
  default     = true
}
// GROUP 6: Network

variable "create_network" {
  description = "Indicate if the deployment has to use a network that already exists. {{UIMeta group=0 order=601 }}"
  type        = bool
  default     = true
}

variable "network_name" {
  description = "Name to be assigned to the network. {{UIMeta group=0 order=602 }}"
  type        = string
  default     = "vpc-network"
}

variable "subnet_name" {
  description = "Name to be assigned to the subnet. {{UIMeta group=0 order=603 }}"
  type        = string
  default     = "vpc-subnet"
}

// GROUP 11: GKE

variable "create_autopilot_cluster" {
  description = "Indicate if a GKE autopilot cluster is requred, otherwise a standard cluster will be created. {{UIMeta group=0 order=1102 }}"
  type        = bool
  default     = true
}

variable "release_channel" {
  description = "Enroll the GKE cluster in this release channel. {{UIMeta group=0 order=1103 }}"
  type        = string
  default     = "REGULAR"
}

// GROUP 12: Application

variable "deploy_application" {
  description = "Deploy microservices banking application. {{UIMeta group=3 order=1201 }}"
  type        = bool
  default     = true
}
