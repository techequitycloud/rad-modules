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
  default     = "This module deploys a Google Cloud Migration Center assessment environment. It provisions a Windows Server 2022 VM with the MC Discovery Client (MCDCv6) pre-installed, Debian Linux target VMs for live network scanning, and automatically initialises the Migration Center service and registers the discovery source. AWS EC2 inventory can be imported automatically when credentials are provided. Asset groups, migration preferences, and TCO reports are created as hands-on lab exercises using the Migration Center console."
}

variable "module_documentation" {
  description = "URL linking to the external documentation for this module. Displayed in the platform UI as a help reference. Metadata only. {{UIMeta group=0 order=1 }}"
  type        = string
  default     = "https://github.com/techequitycloud/rad-modules/blob/main/docs/labs/Migration_Center.md"
}

variable "module_dependency" {
  description = "Ordered list of module names that must be fully deployed before this module can be deployed. {{UIMeta group=0 order=101 }}"
  type        = list(string)
  default     = ["GCP Project"]
}

variable "module_services" {
  description = "List of cloud service tags associated with this module. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP", "Migration Center", "Compute Engine", "Cloud Storage", "Cloud IAM", "VPC Network"]
}

variable "credit_cost" {
  description = "Number of platform credits consumed when this module is deployed. {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 200
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
  description = "Set to false (default) to restrict this module to platform administrators only. Set to true to make it visible and deployable by all platform users. {{UIMeta group=0 order=106 }}"
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

// SECTION 2: Main

variable "project_id" {
  description = "GCP project ID where Migration Center resources will be deployed. Must already exist and the service account must hold roles/owner. {{UIMeta group=1 order=101 updatesafe }}"
  type        = string
  default     = null
}

variable "region" {
  description = "GCP region where all resources will be deployed (e.g. 'us-central1'). Migration Center must be available in this region. {{UIMeta group=1 order=103 }}"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone where Compute Engine instances will be deployed (e.g. 'us-central1-a'). {{UIMeta group=1 order=104 }}"
  type        = string
  default     = "us-central1-a"
}

// SECTION 2: Networking

variable "create_vpc" {
  description = "Set to true (default) to create a dedicated VPC network for this lab. Set to false to use an existing VPC. {{UIMeta group=2 order=201 }}"
  type        = bool
  default     = true
}

variable "create_default_firewall_rules" {
  description = "Set to true (default) to create the four Google-default firewall rules (allow-internal, allow-ssh, allow-rdp, allow-icmp) on the VPC. Set to false if these rules already exist on the target network. {{UIMeta group=2 order=202 }}"
  type        = bool
  default     = true
}

variable "internal_traffic_cidr" {
  description = "CIDR block used as the source range for the allow-internal firewall rule. Matches the default VPC auto-mode subnet range. {{UIMeta group=2 order=203 }}"
  type        = string
  default     = "10.128.0.0/9"
}

// SECTION 3: Compute Engine

variable "create_windows_vm" {
  description = "Set to true (default) to deploy the Windows Server 2022 VM that hosts the MC Discovery Client. The startup script automatically installs MCDCv6. {{UIMeta group=3 order=301 }}"
  type        = bool
  default     = true
}

variable "windows_vm_machine_type" {
  description = "Machine type for the Windows MCDCv6 host VM. e2-medium provides sufficient resources for running the discovery client. {{UIMeta group=3 order=302 }}"
  type        = string
  default     = "e2-medium"
}

variable "windows_vm_boot_disk_size_gb" {
  description = "Boot disk size in GB for the Windows VM. Minimum 50 GB recommended for Windows Server 2022 plus MCDCv6. {{UIMeta group=3 order=303 }}"
  type        = number
  default     = 50
}

variable "linux_vm_count" {
  description = "Number of Debian Linux VMs to deploy as discovery scan targets. The MCDCv6 scanner will discover and inventory these VMs. {{UIMeta group=3 order=304 }}"
  type        = number
  default     = 3
}

variable "linux_vm_machine_type" {
  description = "Machine type for each Linux discovery target VM. e2-medium is sufficient for lab purposes. {{UIMeta group=3 order=305 }}"
  type        = string
  default     = "e2-medium"
}

variable "linux_vm_boot_disk_size_gb" {
  description = "Boot disk size in GB for each Linux target VM. {{UIMeta group=3 order=306 }}"
  type        = number
  default     = 20
}

// SECTION 7: SSH Key Storage

variable "create_ssh_key_bucket" {
  description = "Set to true (default) to create a Cloud Storage bucket and store the generated SSH private key. The bucket name is surfaced in Terraform outputs for easy retrieval. {{UIMeta group=7 order=701 }}"
  type        = bool
  default     = true
}

// SECTION 8: Migration Center

variable "initialize_migration_center" {
  description = "Set to true (default) to automatically initialize the Migration Center service and register the MCDCv6 discovery source. AWS EC2 inventory is also imported when aws_access_key_id is provided. Asset groups, preferences, and reports are created as lab exercises. {{UIMeta group=8 order=801 }}"
  type        = bool
  default     = true
}

variable "mc_discovery_client_name" {
  description = "Name to register for the MC Discovery Client data source. This name appears in the Migration Center console and must match what you enter in the MCDCv6 UI during login. {{UIMeta group=8 order=802 }}"
  type        = string
  default     = "mc-discovery-client"
}

variable "aws_access_key_id" {
  description = "Bootstrap AWS Access Key ID with IAM write permissions (iam:CreateUser, iam:CreatePolicy, iam:AttachUserPolicy, iam:CreateAccessKey and their Delete/Detach counterparts). The module uses these credentials to automatically provision a scoped EC2-read-only IAM user; EC2 discovery runs under the generated key, not these bootstrap credentials. Leave empty to skip AWS integration entirely. {{UIMeta group=8 order=803 updatesafe }}"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "Bootstrap AWS Secret Access Key corresponding to the Access Key ID above. {{UIMeta group=8 order=804 updatesafe }}"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region to discover EC2 instances from (e.g. 'us-east-1'). {{UIMeta group=8 order=805 updatesafe }}"
  type        = string
  default     = "us-east-1"
}

