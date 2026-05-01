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
  # Region assignments - maps cluster index to region
  region_assignments = {
    for i in range(var.cluster_size) : i => var.available_regions[i % length(var.available_regions)]
  }

  # Cluster configurations - references region assignments
  cluster_configs = {
    for i in range(var.cluster_size) : "cluster${i + 1}" => {
      gke_cluster_name = "gke-cluster-${i + 1}"
      region           = local.region_assignments[i]

      # Primary subnet: 10.X.0.0/20 (4,096 IPs for nodes)
      ip_cidr_range = cidrsubnet("10.0.0.0/8", 12, i * 4)

      # Pod range: 10.X.16.0/20 (4,096 IPs for pods)
      pod_ip_range   = "pod-ip-range-${i + 1}"
      pod_cidr_block = cidrsubnet("10.0.0.0/8", 12, i * 4 + 1)

      # Service range: 10.X.32.0/20 (4,096 IPs for services)
      service_ip_range   = "service-ip-range-${i + 1}"
      service_cidr_block = cidrsubnet("10.0.0.0/8", 12, i * 4 + 2)
    }
  }
}

// SECTION 1: Provider

variable "module_description" {
  description = "Human-readable description of this module displayed to users in the platform UI. Changing this will update the description shown in the module catalog. Defaults to the module's built-in description. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = "This module deploys an advanced, microservice banking demo application on Google Kubernetes Engine (GKE) across multiple clusters, utilizing Cloud Service Mesh for enhanced security and multi-cluster management. It serves as a reference implementation for highly scalable, secure, and feature-rich banking platforms. This module is for educational purposes only."
}

variable "module_dependency" {
  description = "Ordered list of module names that must be fully deployed before this module can be deployed. The platform enforces this sequence. Defaults to ['GCP Project']. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP Project"]
}

variable "module_services" {
  description = "List of cloud service tags associated with this module, used for display and filtering in the platform UI. Represents the key services provisioned by this module. Defaults to the core services this module provisions. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP", "GKE", "Anthos Service Mesh", "Cloud IAM", "Cloud Networking"]
}

variable "credit_cost" {
  description = "Number of platform credits consumed when this module is deployed. Credits are purchased separately; if require_credit_purchases is true, users must have sufficient credit balance before deploying. Defaults to 150. {{UIMeta group=0 order=104 }}"
  type        = number
  default     = 150
}

variable "require_credit_purchases" {
  description = "Set to true to require users to hold a credit balance before deploying this module. When false (default), the module can be deployed regardless of credit balance. {{UIMeta group=0 order=105 }}"
  type        = bool
  default     = false
}

variable "enable_purge" {
  description = "Set to true (default) to allow platform administrators to permanently delete all resources created by this module via the platform purge operation. Set to false to prevent purge operations on this deployment. {{UIMeta group=0 order=106 }}"
  type        = bool
  default     = true
}

variable "public_access" {
  description = "Set to true (default) to make this module visible and deployable by all platform users. Set to false to restrict the module to platform administrators only. {{UIMeta group=0 order=106 }}"
  type        = bool
  default     = true
}

variable "resource_creator_identity" {
  description = "Email of the Terraform service account used to provision resources in the destination GCP project (format: name@project-id.iam.gserviceaccount.com). This account must hold roles/owner in the destination project. Defaults to the platform's built-in provisioning service account; only override if using a custom service account. {{UIMeta group=0 order=102 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of Google account email addresses granted cluster-admin privileges on all GKE clusters in this deployment (e.g. ['user@example.com']). Defaults to an empty list (no additional admin users). {{UIMeta group=0 order=107 updatesafe }}"
  type        = list(string)
  default     = []
}

variable "deployment_id" {
  description = "Short alphanumeric suffix appended to resource names to ensure uniqueness across deployments (e.g. 'abc123'). Leave blank (default null) to have the platform automatically generate a random suffix. Modifying this after initial deployment will force recreation of all named resources. {{UIMeta group=0 order=108 }}"
  type        = string
  default     = null
}

// SECTION 2: Main

variable "existing_project_id" {
  description = "GCP project ID of the destination project where the GKE clusters and banking application will be deployed (format: lowercase letters, digits, and hyphens, e.g. 'my-project-123'). This project must already exist and the resource_creator_identity service account must hold roles/owner in it. Required; no default. {{UIMeta group=1 order=101 updatesafe }}"
  type        = string
}

variable "available_regions" {
  description = "List of GCP regions available for cluster deployment (e.g. ['us-west1', 'us-east1']). Clusters are assigned to regions in round-robin order based on their index; if fewer regions than clusters are specified, regions are cycled (e.g. 2 regions for 4 clusters: cluster1=us-west1, cluster2=us-east1, cluster3=us-west1, cluster4=us-east1). Must contain at least one entry. Defaults to ['us-west1', 'us-east1']. {{UIMeta group=1 order=102 }}"
  type        = list(string)
  default     = ["us-west1", "us-east1"]
}

// SECTION 2: Network

variable "create_network" {
  description = "Set to true (default) to create a new shared VPC network for all GKE clusters. Set to false to use an existing network identified by network_name. Each cluster receives its own subnet automatically derived from the cluster index. {{UIMeta group=2 order=201 }}"
  type        = bool
  default     = true
}

variable "network_name" {
  description = "Name of the shared VPC network used by all clusters. When create_network is true, this is the name given to the newly created network. When create_network is false, this identifies the existing network to use. Defaults to 'vpc-network'. {{UIMeta group=2 order=202 }}"
  type        = string
  default     = "vpc-network"
}

variable "subnet_name" {
  description = "Base name for per-cluster subnets. Each cluster receives a subnet named '<subnet_name>-cluster<N>' (e.g. 'vpc-subnet-cluster1', 'vpc-subnet-cluster2'). Only used when create_network is true. Defaults to 'vpc-subnet'. {{UIMeta group=2 order=203 }}"
  type        = string
  default     = "vpc-subnet"
}

// SECTION 3: GKE

variable "create_autopilot_cluster" {
  description = "Set to true (default) to create GKE Autopilot clusters, where node provisioning and scaling are fully managed by Google. Set to false to create Standard clusters where node pools are manually configured. Applies to all clusters in this deployment. Autopilot is recommended for most workloads; Standard offers more control over node configuration. {{UIMeta group=3 order=301 }}"
  type        = bool
  default     = true
}

variable "release_channel" {
  description = "GKE release channel controlling the frequency and type of automatic upgrades for all clusters. Valid values: 'RAPID' (latest features, upgraded frequently), 'REGULAR' (balanced stability and features, default), 'STABLE' (least frequent upgrades, most stable), 'NONE' (manual upgrades only). Defaults to 'REGULAR'. {{UIMeta group=3 order=302 }}"
  type        = string
  default     = "REGULAR"
}

variable "cluster_size" {
  description = "Number of GKE clusters to create for the multi-cluster banking application deployment. Minimum 2 for meaningful multi-cluster demonstration; maximum is limited by the available quota in the selected regions. Regions are assigned from available_regions in round-robin order. Defaults to 2. {{UIMeta group=3 order=303 }}"
  type        = number
  default     = 2
}

// SECTION 4: Services

variable "enable_services" {
  description = "Set to true (default) to automatically enable the required GCP project APIs (e.g. container.googleapis.com, mesh.googleapis.com). Set to false when deploying into an existing project where APIs are already enabled to avoid permission errors. {{UIMeta group=0 order=401 }}"
  type        = bool
  default     = true
}

variable "enable_cloud_service_mesh" {
  description = "Set to true (default) to install and configure Cloud Service Mesh (Google-managed Istio) across all clusters, enabling mTLS encryption, cross-cluster traffic management, and unified observability. Requires the mesh.googleapis.com API. Set to false to skip service mesh installation. {{UIMeta group=4 order=401 }}"
  type        = bool
  default     = true
}

variable "cloud_service_mesh_version" {
  description = "Version of Cloud Service Mesh to install across all clusters (format: major.minor.patch-asm.N, e.g. '1.23.4-asm.1'). Only used when enable_cloud_service_mesh is true. Defaults to '1.23.4-asm.1'. Must be compatible with the GKE cluster versions and release channel. {{UIMeta group=4 order=402 }}"
  type        = string
  default     = "1.23.4-asm.1"
}

// SECTION 5: Application

variable "deploy_application" {
  description = "Set to true (default) to deploy the Bank of Anthos microservices banking demo application across all GKE clusters after they are created. Set to false to provision only the cluster infrastructure without deploying the application. {{UIMeta group=5 order=501 }}"
  type        = bool
  default     = true
}
