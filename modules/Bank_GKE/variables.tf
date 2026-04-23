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

// SECTION 1: Provider

variable "module_description" {
  description = "Human-readable description of this module displayed to users in the platform UI. Changing this will update the description shown in the module catalog. Defaults to the module's built-in description. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = "This module deploys an advanced, microservice banking demo application on Google Kubernetes Engine (GKE), utilizing Cloud Service Mesh for enhanced security and multi-cluster management. It serves as a reference implementation for highly scalable, secure, and feature-rich banking platforms. This module is for educational purposes only."
}

variable "module_dependency" {
  description = "Ordered list of module names that must be fully deployed before this module can be deployed. The platform enforces this sequence. Defaults to ['GCP Project']. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP Project"]
}

variable "module_services" {
  description = "List of cloud service tags associated with this module, used for display and filtering in the platform UI. Represents the key services provisioned by this module. Defaults to the core services this module provisions. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP", "GKE", "Anthos Service Mesh", "Anthos Config Management", "Cloud IAM", "Cloud Networking"]
}

variable "credit_cost" {
  description = "Number of platform credits consumed when this module is deployed. Credits are purchased separately; if require_credit_purchases is true, users must have sufficient credit balance before deploying. Defaults to 200. {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 200
}

variable "require_credit_purchases" {
  description = "Set to true to require users to hold a credit balance before deploying this module. When false (default), the module can be deployed regardless of credit balance. {{UIMeta group=0 order=104 }}"
  type        = bool
  default     = false
}

variable "enable_purge" {
  description = "Set to true (default) to allow platform administrators to permanently delete all resources created by this module via the platform purge operation. Set to false to prevent purge operations on this deployment. {{UIMeta group=0 order=105 }}"
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
  description = "List of Google account email addresses granted cluster-admin privileges on the GKE cluster and access via the Google Cloud console (e.g. ['user@example.com']). Defaults to an empty list (no additional admin users). {{UIMeta group=0 order=103 updatesafe }}"
  type        = list(string)
  default     = []
}

variable "deployment_id" {
  description = "Short alphanumeric suffix appended to resource names to ensure uniqueness across deployments (e.g. 'abc123'). Leave blank (default null) to have the platform automatically generate a random suffix. Modifying this after initial deployment will force recreation of all named resources."
  type        = string
  default     = null
}

// SECTION 2: Main

variable "existing_project_id" {
  description = "GCP project ID of the destination project where the GKE cluster and banking application will be deployed (format: lowercase letters, digits, and hyphens, e.g. 'my-project-123'). This project must already exist and the resource_creator_identity service account must hold roles/owner in it. Leave blank to use the default project. {{UIMeta group=1 order=101 updatesafe }}"
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "GCP region where the GKE cluster, VPC, and all supporting resources will be deployed (e.g. 'us-central1', 'europe-west1'). Defaults to 'us-central1'. Deployment may fail if sufficient resource quota is not available in the selected region. {{UIMeta group=1 order=102 }}"
  type        = string
  default     = "us-central1"
}

// SECTION 3: Network

variable "create_network" {
  description = "Set to true (default) to create a new VPC network and subnet for the GKE cluster. Set to false to use an existing network and subnet identified by network_name and subnet_name. {{UIMeta group=2 order=201 }}"
  type        = bool
  default     = true
}

variable "network_name" {
  description = "Name of the VPC network. When create_network is true, this is the name given to the newly created network. When create_network is false, this identifies the existing network to use. Defaults to 'vpc-network'. {{UIMeta group=2 order=202 }}"
  type        = string
  default     = "vpc-network"
}

variable "subnet_name" {
  description = "Name of the subnet within the VPC network. When create_network is true, this is the name given to the newly created subnet. When create_network is false, this identifies the existing subnet to use. Defaults to 'vpc-subnet'. {{UIMeta group=2 order=203 }}"
  type        = string
  default     = "vpc-subnet"
}

variable "ip_cidr_ranges" {
  description = "Set of IPv4 CIDR blocks for the subnet primary and secondary ranges (e.g. ['10.132.0.0/16', '192.168.1.0/24']). Only used when create_network is true. The first CIDR is the primary node range; additional CIDRs are secondary ranges for pods and services. Defaults to ['10.132.0.0/16', '192.168.1.0/24']. {{UIMeta group=2 order=204 }}"
  type        = set(string)
  default     = ["10.132.0.0/16", "192.168.1.0/24"]
}

// SECTION 5: CLUSTER

variable "create_cluster" {
  description = "Set to true (default) to create a new GKE cluster. Set to false to deploy the banking application onto an existing cluster identified by gke_cluster. {{UIMeta group=5 order=501 }}"
  type        = bool
  default     = true
}

variable "create_autopilot_cluster" {
  description = "Set to true (default) to create a GKE Autopilot cluster, where node provisioning and scaling are fully managed by Google. Set to false to create a Standard cluster where node pools are manually configured. Autopilot is recommended for most workloads; Standard offers more control over node configuration. {{UIMeta group=5 order=502 }}"
  type        = bool
  default     = true
}

variable "gke_cluster" {
  description = "Name of the GKE cluster. When create_cluster is true, this is the name given to the newly created cluster. When create_cluster is false, this identifies the existing cluster to use. Defaults to 'gke-cluster'. {{UIMeta group=5 order=503 }}"
  type        = string
  default     = "gke-cluster"
}

variable "release_channel" {
  description = "GKE release channel controlling the frequency and type of automatic cluster upgrades. Valid values: 'RAPID' (latest features, upgraded frequently), 'REGULAR' (balanced stability and features, default), 'STABLE' (least frequent upgrades, most stable), 'NONE' (manual upgrades only). Defaults to 'REGULAR'. {{UIMeta group=5 order=504 }}"
  type        = string
  default     = "REGULAR"
}

variable "pod_ip_range" {
  description = "Alias name for the secondary IP range used to assign IP addresses to Pods in the GKE cluster. This name is referenced when creating the subnet secondary range. Defaults to 'pod-ip-range'. Must be unique within the subnet. {{UIMeta group=0 order=505 }}"
  type        = string
  default     = "pod-ip-range"
}

variable "pod_cidr_block" {
  description = "IPv4 CIDR block assigned to Pods running in the GKE cluster (e.g. '10.62.128.0/17'). Must be large enough to accommodate all pods across all nodes; a /17 supports up to 32,768 pod IPs. Must not overlap with the node or service CIDR ranges. Defaults to '10.62.128.0/17'. {{UIMeta group=5 order=506 }}"
  type        = string
  default     = "10.62.128.0/17"
}

variable "service_ip_range" {
  description = "Alias name for the secondary IP range used to assign IP addresses to Kubernetes Services (ClusterIP) in the GKE cluster. This name is referenced when creating the subnet secondary range. Defaults to 'service-ip-range'. Must be unique within the subnet. {{UIMeta group=0 order=507 }}"
  type        = string
  default     = "service-ip-range"
}

variable "service_cidr_block" {
  description = "IPv4 CIDR block assigned to Kubernetes Services (ClusterIP) in the GKE cluster (e.g. '10.64.128.0/20'). A /20 supports up to 4,096 service IPs. Must not overlap with the node or pod CIDR ranges. Defaults to '10.64.128.0/20'. {{UIMeta group=5 order=508 }}"
  type        = string
  default     = "10.64.128.0/20"
}

// SECTION 6: FEATURES

variable "enable_services" {
  description = "Set to true (default) to automatically enable the required GCP project APIs (e.g. container.googleapis.com, mesh.googleapis.com). Set to false when deploying into an existing project where APIs are already enabled to avoid permission errors. {{UIMeta group=0 order=600 }}"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Set to true (default) to enable Google Cloud Managed Service for Prometheus and Cloud Monitoring dashboards for the GKE cluster. Provides metrics, alerting, and observability for cluster workloads. Set to false to skip monitoring configuration. {{UIMeta group=6 order=601 }}"
  type        = bool
  default     = true
}

variable "enable_cloud_service_mesh" {
  description = "Set to true (default) to install and configure Cloud Service Mesh (Google-managed Istio), which provides mTLS encryption, traffic management, and observability between microservices. Requires the mesh.googleapis.com API. Set to false to skip service mesh installation. {{UIMeta group=6 order=602 }}"
  type        = bool
  default     = true
}

variable "cloud_service_mesh_version" {
  description = "Version of Cloud Service Mesh to install (format: major.minor.patch-asm.N, e.g. '1.23.4-asm.1'). Only used when enable_cloud_service_mesh is true. Defaults to '1.23.4-asm.1'. Must be a version compatible with the GKE cluster version and release channel. {{UIMeta group=6 order=603 }}"
  type        = string
  default     = "1.23.4-asm.1"
}

variable "enable_config_management" {
  description = "Set to true to install Anthos Config Management (ACM), which syncs Kubernetes configuration from a Git repository specified by config_sync_repo and config_sync_policy_dir. Defaults to false. Requires enable_cloud_service_mesh to also be true for full functionality. {{UIMeta group=6 order=604 }}"
  type        = bool
  default     = false
}

variable "config_management_version" {
  description = "Version of Anthos Config Management to install (format: major.minor.patch, e.g. '1.22.0'). Only used when enable_config_management is true. Defaults to '1.22.0'. Must be compatible with the GKE cluster version. {{UIMeta group=6 order=605 }}"
  type        = string
  default     = "1.22.0"
}

variable "config_sync_repo" {
  description = "URL of the Git repository from which Anthos Config Sync will pull Kubernetes manifests (e.g. 'https://github.com/org/repo'). Only used when enable_config_management is true. Defaults to the Google Cloud Platform ACM samples repository. The repository must be publicly accessible or credentials must be configured separately. {{UIMeta group=6 order=606 }}"
  type        = string
  default     = "https://github.com/GoogleCloudPlatform/anthos-config-management-samples"
}

variable "config_sync_policy_dir" {
  description = "Path within the config_sync_repo Git repository containing the root Kubernetes configuration to sync (e.g. 'config-sync-quickstart/multirepo/root'). Only used when enable_config_management is true. Defaults to the quickstart multi-repo root directory. {{UIMeta group=6 order=607 }}"
  type        = string
  default     = "config-sync-quickstart/multirepo/root"
}

// SECTION 8: Application

variable "deploy_application" {
  description = "Set to true (default) to deploy the Bank of Anthos microservices banking demo application onto the GKE cluster after it is created. Set to false to provision only the cluster infrastructure without deploying the application. {{UIMeta group=7 order=701 }}"
  type        = bool
  default     = true
}
