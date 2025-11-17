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
**Purpose:** This module configures the Open Source Istio service mesh on a Google Kubernetes Engine (GKE) cluster. A service mesh is a dedicated infrastructure layer for making service-to-service communication safe, fast, and reliable.

**What it does:**
- Creates a GKE cluster and configures Istio on the cluster.
- Enables you to choose between two different modes of Istio: ambient mesh or sidecar mesh.
- Demonstrates advanced features for managing and securing your microservices, such as traffic management, security, and observability.

**Dependencies:** This module deploys into an existing Google Cloud project. We recommend using the Google Cloud project exclusively for this deployment. 
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
  default     = ["GCP", "GKE", "Istio", "Cloud IAM", "Cloud Networking"]
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

// GROUP 2: Main 

variable "deployment_id" {
  description = "Unique ID suffix for resources.  Leave blank to generate random ID."
  type        = string
  default     = null
}

variable "existing_project_id" {
  description = "Enter the project ID of the destination project. {{UIMeta group=2 order=200 updatesafe }}"
  type        = string
}

variable "enable_services" {
  description = "Enable project APIs.  When using an existing project, this is set to false. {{UIMeta group=0 order=203 }}"
  type        = bool
  default     = true
}

variable "deploy_application" {
  description = "Deploy application. {{UIMeta group=0 order=204 }}"
  type        = bool
  default     = true
}

variable "region" {
  description = "The region where Google Cloud resources will be deployed. Deployment may fail if sufficient resource quota is not available in selected region. List - https://cloud.google.com/compute/docs/regions-zones#available. {{UIMeta group=2 order=205 }}"
  type        = string
  default     = "us-central1"
}

// GROUP 3: Network

variable "create_network" {
  description = "Indicate if the deployment has to use a network that already exists. {{UIMeta group=0 order=301 }}"
  type        = bool
  default     = true
}

variable "network_name" {
  description = "Name to be assigned to the network. {{UIMeta group=0 order=302 }}"
  type        = string
  default     = "vpc-network"
}

variable "subnet_name" {
  description = "Name to be assigned to the subnet. {{UIMeta group=0 order=303 }}"
  type        = string
  default     = "vpc-subnet"
}

variable "ip_cidr_ranges" {
  description = "CIDR Range for subnet (if required). {{UIMeta group=0 order=304 }}"
  type        = set(string)
  default     = ["10.132.0.0/16","192.168.1.0/24"]
}

// GROUP 4: GKE

variable "gke_cluster" {
  description = "Name that will be assigned to the GKE cluster. {{UIMeta group=0 order=401 }}"
  type        = string
  default     = "gke-cluster"
}

variable "release_channel" {
  description = "Enroll the GKE cluster in this release channel. {{UIMeta group=0 order=403 }}"
  type        = string
  default     = "REGULAR"
}

variable "pod_ip_range" {
  description = "Range name for the pod IP addresses. {{UIMeta group=0 order=404 }}"
  type        = string
  default     = "pod-ip-range"
}

variable "pod_cidr_block" {
  description = "CIDR block to be assigned to pods running in the GKE cluster. {{UIMeta group=0 order=405 }}"
  type        = string
  default     = "10.62.128.0/17"
}

variable "service_ip_range" {
  description = "Name for the IP range for services. {{UIMeta group=0 order=406 }}"
  type        = string
  default     = "service-ip-range"
}

variable "service_cidr_block" {
  description = "CIDR block to be assigned to services running in the GKE cluster. {{UIMeta group=0 order=407 }}"
  type        = string
  default     = "10.64.128.0/20"
}

// GROUP 5: GKE

variable "istio_version" {
  description = "The version of Istio to install. {{UIMeta group=0 order=501 }}"
  type        = string
  default     = "1.24.2"
}

variable "install_ambient_mesh" {
  description = "Install ambient mesh. When deselected, sidecar mesh is configured. {{UIMeta group=3 order=502 }}"
  type        = bool
  default     = false
}
