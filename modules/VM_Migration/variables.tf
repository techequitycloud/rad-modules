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
  default     = "This module deploys a fully configured Google Cloud Migration Center assessment environment. Migration Center is Google Cloud's free tool for discovering, analyzing, and planning migrations from on-premises or other cloud environments. The module provisions a Windows Server 2022 VM with the MC Discovery Client (MCDCv6) pre-installed, Debian Linux target VMs for live network scanning, and runs all Migration Center setup steps automatically — including initializing the service, registering the discovery source, importing sample AWS data, creating asset groups, configuring migration preferences, and generating TCO and inventory reports. Users connect via RDP and complete only the Google OAuth login step before exploring a fully populated Migration Center environment."
}

variable "module_documentation" {
  description = "URL linking to the external documentation for this module. Displayed in the platform UI as a help reference. Metadata only. {{UIMeta group=0 order=1 }}"
  type        = string
  default     = "https://github.com/techequitycloud/rad-modules/blob/main/modules/VM_Migration/LAB_GUIDE.md"
}

variable "module_dependency" {
  description = "Ordered list of module names that must be fully deployed before this module can be deployed. {{UIMeta group=0 order=101 }}"
  type        = list(string)
  default     = ["GCP Project"]
}

variable "module_services" {
  description = "List of cloud service tags associated with this module. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP", "Migration Center", "Compute Engine", "Cloud Storage", "Cloud IAM"]
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

// SECTION 3: Networking

variable "create_vpc" {
  description = "Set to true (default) to create a dedicated VPC network for this lab. Set to false to use an existing VPC. {{UIMeta group=3 order=301 }}"
  type        = bool
  default     = true
}

variable "internal_traffic_cidr" {
  description = "CIDR block used as the source range for the allow-internal firewall rule. Matches the default VPC auto-mode subnet range. {{UIMeta group=3 order=302 }}"
  type        = string
  default     = "10.128.0.0/9"
}

// SECTION 4: Firewall Rules

variable "create_default_firewall_rules" {
  description = "Set to true (default) to create the four Google-default firewall rules (allow-internal, allow-ssh, allow-rdp, allow-icmp) on the VPC. Set to false if these rules already exist on the target network. {{UIMeta group=4 order=401 }}"
  type        = bool
  default     = true
}

// SECTION 5: Windows VM

variable "create_windows_vm" {
  description = "Set to true (default) to deploy the Windows Server 2022 VM that hosts the MC Discovery Client. The startup script automatically installs MCDCv6 and pre-stages AWS import data. {{UIMeta group=5 order=501 }}"
  type        = bool
  default     = true
}

variable "windows_vm_machine_type" {
  description = "Machine type for the Windows MCDCv6 host VM. e2-medium provides sufficient resources for running the discovery client. {{UIMeta group=5 order=502 }}"
  type        = string
  default     = "e2-medium"
}

variable "windows_vm_boot_disk_size_gb" {
  description = "Boot disk size in GB for the Windows VM. Minimum 50 GB recommended for Windows Server 2022 plus MCDCv6. {{UIMeta group=5 order=503 }}"
  type        = number
  default     = 50
}

// SECTION 6: Linux Target VMs

variable "linux_vm_count" {
  description = "Number of Debian Linux VMs to deploy as discovery scan targets. The MCDCv6 scanner will discover and inventory these VMs. {{UIMeta group=6 order=601 }}"
  type        = number
  default     = 3
}

variable "linux_vm_machine_type" {
  description = "Machine type for each Linux discovery target VM. e2-medium is sufficient for lab purposes. {{UIMeta group=6 order=602 }}"
  type        = string
  default     = "e2-medium"
}

variable "linux_vm_boot_disk_size_gb" {
  description = "Boot disk size in GB for each Linux target VM. {{UIMeta group=6 order=603 }}"
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
  description = "Set to true (default) to automatically initialize the Migration Center service, create a discovery source, import sample AWS data, create asset groups and migration preferences, and trigger report generation. {{UIMeta group=8 order=801 }}"
  type        = bool
  default     = true
}

variable "mc_discovery_client_name" {
  description = "Name to register for the MC Discovery Client data source. This name appears in the Migration Center console and must match what you enter in the MCDCv6 UI during login. {{UIMeta group=8 order=802 }}"
  type        = string
  default     = "mc-discovery-client"
}

variable "import_aws_sample_data" {
  description = "Set to true (default) to automatically download and import the sample AWS CSV export data into Migration Center. This populates the asset inventory with simulated AWS VM data alongside the live scan results. {{UIMeta group=8 order=803 }}"
  type        = bool
  default     = true
}

// SECTION 9: Reports

variable "generate_reports" {
  description = "Set to true (default) to automatically create asset groups, migration preferences, and trigger TCO report generation in Migration Center after the AWS data import completes. {{UIMeta group=9 order=901 }}"
  type        = bool
  default     = true
}

variable "mc_report_name" {
  description = "Name for the generated TCO and detailed pricing report in Migration Center. {{UIMeta group=9 order=902 }}"
  type        = string
  default     = "lab-tco-report"
}
