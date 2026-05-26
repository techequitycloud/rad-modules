/**
 * Copyright 2024 Google LLC
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
  description = "Human-readable description of this module displayed to users in the platform UI. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = "This module provisions the complete Google Cloud infrastructure required to run a Migrate to Containers (M2C) lab — the automated path for replatforming VM-based Linux workloads to containers on Google Kubernetes Engine (GKE) without manual application refactoring. Migrate to Containers analyses running Linux VMs using the mcdc CLI, auto-generates production-ready Dockerfiles and Kubernetes manifests, and migrates persistent data volumes to GKE PersistentVolumes. This module deploys two Ubuntu source VMs (PostgreSQL 14 and Apache Tomcat 10 running the Spring PetClinic application), a Migrate to Containers CLI workstation pre-installed with the m2c toolchain, Docker, kubectl, and Skaffold, and a three-node GKE cluster ready to receive migrated workloads — providing a complete, hands-on environment to practise the full container migration lifecycle from workload assessment through to GKE deployment and horizontal pod autoscaling."
}

variable "module_documentation" {
  description = "URL linking to the external documentation for this module. Displayed in the platform UI as a help reference. Metadata only. {{UIMeta group=0 order=1 }}"
  type        = string
  default     = "https://github.com/techequitycloud/rad-modules/blob/main/modules/Container_Migration/LAB_GUIDE.md"
}

variable "module_dependency" {
  description = "Ordered list of module names that must be fully deployed before this module can be deployed. {{UIMeta group=0 order=101 }}"
  type        = list(string)
  default     = ["GCP Project"]
}

variable "module_services" {
  description = "List of cloud service tags associated with this module. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP", "GKE", "Migrate to Containers", "Cloud Compute", "Cloud Networking", "Cloud IAM"]
}

variable "credit_cost" {
  description = "Number of platform credits consumed when this module is deployed. {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 20
}

variable "require_credit_purchases" {
  description = "Set to true to require users to hold a credit balance before deploying this module. {{UIMeta group=0 order=104 }}"
  type        = bool
  default     = false
}

variable "enable_purge" {
  description = "Set to true (default) to allow platform administrators to permanently delete all resources created by this module. {{UIMeta group=0 order=105 }}"
  type        = bool
  default     = true
}

variable "public_access" {
  description = "Set to true (default) to make this module visible and deployable by all platform users. {{UIMeta group=0 order=106 }}"
  type        = bool
  default     = true
}

variable "shared_users" {
  description = "List of users who can view and deploy this module regardless of the public_access setting. Enter one or more user email addresses. Metadata only — not referenced within the Terraform module execution; consumed by the deployment platform only. {{UIMeta group=0 order=107 }}"
  type        = list(string)
  default     = []
}

variable "resource_creator_identity" {
  description = "Email of the Terraform service account used to provision resources (format: name@project-id.iam.gserviceaccount.com). Must hold roles/owner in the destination project. {{UIMeta group=0 order=107 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "deployment_id" {
  description = "Short alphanumeric suffix appended to resource names to ensure uniqueness within the project. Set by the platform; leave blank to use no suffix. {{UIMeta group=0 order=108 }}"
  type        = string
  default     = null
}

variable "enable_services" {
  description = "Set to true (default) to automatically enable required GCP project APIs. Set to false when APIs are already enabled. {{UIMeta group=0 order=109 }}"
  type        = bool
  default     = true
}

// SECTION 2: Main

variable "project_id" {
  description = "GCP project ID where Container Migration resources will be deployed. Must already exist and the service account must hold roles/owner. {{UIMeta group=1 order=101 updatesafe }}"
  type        = string
  default     = null
}

variable "region" {
  description = "GCP region where the GKE cluster and VMs will be deployed (e.g. 'us-central1'). {{UIMeta group=1 order=103 }}"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone where the GKE cluster and VMs will be deployed (e.g. 'us-central1-a'). {{UIMeta group=1 order=104 }}"
  type        = string
  default     = "us-central1-a"
}

// SECTION 3: Network

variable "create_vpc" {
  description = "Set to true (default) to create a new auto-mode VPC network for the lab. Set to false to use an existing VPC. {{UIMeta group=3 order=301 }}"
  type        = bool
  default     = true
}

variable "create_default_firewall_rules" {
  description = "Set to true (default) to create default firewall rules (allow-internal, allow-ssh, allow-icmp) on the VPC. Set to false if these rules already exist on the target network. {{UIMeta group=3 order=302 }}"
  type        = bool
  default     = true
}

variable "internal_traffic_cidr" {
  description = "CIDR block used as the source range for the allow-internal firewall rule. Matches the default VPC auto-mode subnet range. Override if using a custom-mode VPC. {{UIMeta group=3 order=303 }}"
  type        = string
  default     = "10.128.0.0/9"
}

// SECTION 4: Source VMs

variable "postgres_machine_type" {
  description = "Machine type for the PostgreSQL source VM (e.g. 'e2-medium'). This VM runs PostgreSQL 14 and serves as the database migration source. {{UIMeta group=4 order=401 }}"
  type        = string
  default     = "e2-medium"
}

variable "postgres_disk_size_gb" {
  description = "Boot disk size in GB for the PostgreSQL source VM. Minimum 20 GB recommended. {{UIMeta group=4 order=402 }}"
  type        = number
  default     = 20
}

variable "tomcat_machine_type" {
  description = "Machine type for the Tomcat source VM (e.g. 'e2-medium'). This VM runs Apache Tomcat 10 with the Spring PetClinic application. {{UIMeta group=4 order=403 }}"
  type        = string
  default     = "e2-medium"
}

variable "tomcat_disk_size_gb" {
  description = "Boot disk size in GB for the Tomcat source VM. Minimum 20 GB recommended. {{UIMeta group=4 order=404 }}"
  type        = number
  default     = 20
}

// SECTION 5: Migrate to Containers CLI VM

variable "m2c_machine_type" {
  description = "Machine type for the Migrate to Containers CLI VM (e.g. 'e2-standard-4'). This VM requires sufficient CPU and memory to copy and analyse source VM filesystems. {{UIMeta group=5 order=501 }}"
  type        = string
  default     = "e2-standard-4"
}

variable "m2c_disk_size_gb" {
  description = "Boot disk size in GB for the m2c-cli VM. Must be large enough to hold a copy of the source VM filesystems (minimum 200 GB recommended). {{UIMeta group=5 order=502 }}"
  type        = number
  default     = 200
}

// SECTION 6: GKE Cluster

variable "gke_node_machine_type" {
  description = "Machine type for GKE worker nodes (e.g. 'e2-medium'). Used for the default node pool that runs migrated container workloads. {{UIMeta group=6 order=601 }}"
  type        = string
  default     = "e2-medium"
}

variable "gke_node_count" {
  description = "Number of nodes in the GKE default node pool. Minimum 3 recommended to support StatefulSet and Deployment scheduling during the lab. {{UIMeta group=6 order=602 }}"
  type        = number
  default     = 3
}
