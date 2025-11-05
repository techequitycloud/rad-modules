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
  type        = string
  default     = "150"
}

variable "require_credit_purchases" {
  description = "Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=104 }}"
  type        = bool
  default     = false
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=1 order=102 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of trusted users (e.g. `username@abc.com`). {{UIMeta group=0 order=103 updatesafe }}"
  type        = set(string)
  default     = []
}

variable "deployment_id" {
  description = "Unique ID suffix for resources.  Leave blank to generate random ID."
  type        = string
  default     = null
}

// GROUP 5: Main 

variable "existing_project_id" {
  description = "Enter the project ID of the destination project. {{UIMeta group=2 order=200 updatesafe }}"
  type        = string
}

variable "enable_services" {
  description = "Enable project APIs.  When using an existing project, this is set to false. {{UIMeta group=0 order=506 }}"
  type        = bool
  default     = true
}

variable "enable_cloud_service_mesh" {
  description = "Enable Cloud Service Mesh. {{UIMeta group=0 order=507 }}"
  type        = bool
  default     = true
}

variable "cloud_service_mesh_version" {
  description = "Cloud Service Mesh version. {{UIMeta group=0 order=507 }}"
  type        = string
  default     = "1.23.4-asm.1"
}

variable "deploy_application" {
  description = "Deploy microservices banking application. {{UIMeta group=4 order=509 }}"
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
  description = "Select to configure GKE autopilot cluster. When deselected, a standard cluster is created. {{UIMeta group=3 order=1103 }}"
  type        = bool
  default     = true
}

variable "release_channel" {
  description = "Enroll the GKE cluster in this release channel. {{UIMeta group=0 order=1104 }}"
  type        = string
  default     = "REGULAR"
}

variable "cluster_configs" {
  description = "A map of GKE cluster configurations."
  type = map(object({
    gke_cluster_name   = string
    region             = string
    ip_cidr_range      = string
    pod_ip_range       = string
    pod_cidr_block     = string
    service_ip_range   = string
    service_cidr_block = string
  }))
  default = {
    "cluster1" = {
      gke_cluster_name   = "gke-cluster-1"
      region             = "us-central1"
      ip_cidr_range      = "10.132.0.0/16"
      pod_ip_range       = "pod-ip-range-1"
      pod_cidr_block     = "10.62.128.0/17"
      service_ip_range   = "service-ip-range-1"
      service_cidr_block = "10.64.128.0/20"
    },
    "cluster2" = {
      gke_cluster_name   = "gke-cluster-2"
      region             = "us-east1"
      ip_cidr_range      = "10.0.0.0/16"
      pod_ip_range       = "pod-ip-range-2"
      pod_cidr_block     = "10.63.128.0/17"
      service_ip_range   = "service-ip-range-2"
      service_cidr_block = "10.64.16.0/20"
    }
  }
}
