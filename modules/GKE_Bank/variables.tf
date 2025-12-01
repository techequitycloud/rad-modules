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
  default     = "This module deploys an advanced, microservice banking demo application on Google Kubernetes Engine (GKE), utilizing Cloud Service Mesh for enhanced security and multi-cluster management. It serves as a reference implementation for highly scalable, secure, and feature-rich banking platforms. This module is for educational purposes only."
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP Project"]
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP", "GKE", "Anthos Service Mesh", "Anthos Config Management", "Cloud IAM", "Cloud Networking"]
}

variable "credit_cost" {
  description = "Specify the module cost {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 200
}

variable "require_credit_purchases" {
  description = "Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=104 }}"
  type        = bool
  default     = false
}

variable "enable_purge" {
  description = "Set to true to enable the ability to purge this module. {{UIMeta group=0 order=105 }}"
  type        = bool
  default     = true
}

variable "public_access" {
description = "Set to true to enable the module to be available to all platform users. {{UIMeta group=0 order=106 }}"
type = bool
default = false
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=1 order=102 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
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

variable "gcp_region" {
  description = "The region where Compute Instance and VPCs will be deployed. Deployment may fail if sufficient resources are not available in region. {{UIMeta group=2 order=201 }}"
  type        = string
  default     = "us-west1"
}

// GROUP 4: Main

variable "enable_services" {
  description = "Enable project APIs.  When using an existing project, this is set to false. {{UIMeta group=0 order=401 }}"
  type        = bool
  default     = true
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

variable "ip_cidr_ranges" {
  description = "CIDR Range for subnet (if required). {{UIMeta group=0 order=606 }}"
  type        = set(string)
  default     = ["10.132.0.0/16","192.168.1.0/24"]
}

// GROUP 11: GKE


variable "gke_cluster" {
  description = "Name that will be assigned to the GKE cluster. {{UIMeta group=0 order=1101 }}"
  type        = string
  default     = "gke-cluster"
}

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

variable "pod_ip_range" {
  description = "Range name for the pod IP addresses. {{UIMeta group=0 order=1114 }}"
  type        = string
  default     = "pod-ip-range"
}

variable "pod_cidr_block" {
  description = "CIDR block to be assigned to pods running in the GKE cluster. {{UIMeta group=0 order=1115 }}"
  type        = string
  default     = "10.62.128.0/17"
}

variable "service_ip_range" {
  description = "Name for the IP range for services. {{UIMeta group=0 order=1116 }}"
  type        = string
  default     = "service-ip-range"
}

variable "service_cidr_block" {
  description = "CIDR block to be assigned to services running in the GKE cluster. {{UIMeta group=0 order=1117 }}"
  type        = string
  default     = "10.64.128.0/20"
}

// GROUP 12: Application

variable "deploy_application" {
  description = "Deploy microservices banking application. {{UIMeta group=3 order=1201 }}"
  type        = bool
  default     = true
}
