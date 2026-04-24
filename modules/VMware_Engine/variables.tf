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
  default     = "This module deploys Google Cloud VMware Engine infrastructure, including a private cloud, VMware Engine network, VPC peering, network policy, and default VPC firewall rules. It is designed to support VM migration workflows and GCVE lab environments."
}

variable "module_dependency" {
  description = "Ordered list of module names that must be fully deployed before this module can be deployed. {{UIMeta group=0 order=101 }}"
  type        = list(string)
  default     = ["GCP Project"]
}

variable "module_services" {
  description = "List of cloud service tags associated with this module. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP", "VMware Engine", "Cloud Networking", "Cloud IAM"]
}

variable "credit_cost" {
  description = "Number of platform credits consumed when this module is deployed. {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 500
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

variable "resource_creator_identity" {
  description = "Email of the Terraform service account used to provision resources (format: name@project-id.iam.gserviceaccount.com). Must hold roles/owner in the destination project. {{UIMeta group=0 order=107 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "deployment_id" {
  description = "Short alphanumeric suffix appended to resource names to ensure uniqueness. Leave blank to auto-generate."
  type        = string
  default     = null
}

// SECTION 2: Main

variable "existing_project_id" {
  description = "GCP project ID where VMware Engine resources will be deployed. Must already exist and the service account must hold roles/owner. {{UIMeta group=1 order=101 updatesafe }}"
  type        = string
  default     = ""
}

variable "region" {
  description = "GCP region where the private cloud and network policy will be deployed (e.g. 'us-west2'). {{UIMeta group=1 order=102 }}"
  type        = string
  default     = "us-west2"
}

variable "zone" {
  description = "GCP zone where the private cloud will be deployed (e.g. 'us-west2-a'). {{UIMeta group=1 order=103 }}"
  type        = string
  default     = "us-west2-a"
}

variable "enable_services" {
  description = "Set to true (default) to automatically enable required GCP project APIs. Set to false when APIs are already enabled. {{UIMeta group=1 order=104 }}"
  type        = bool
  default     = true
}

// SECTION 3: VMware Engine Network

variable "vmware_engine_network_name" {
  description = "Name of the VMware Engine Network. Must start with 'altostrat-'. Used as the logical backbone for the private cloud. {{UIMeta group=3 order=301 }}"
  type        = string
  default     = "altostrat-vmware-engine-network"

  validation {
    condition     = startswith(var.vmware_engine_network_name, "altostrat-")
    error_message = "vmware_engine_network_name must start with 'altostrat-'."
  }
}

// SECTION 4: Private Cloud

variable "private_cloud_name" {
  description = "Name of the VMware Engine Private Cloud. Must start with 'altostrat-'. {{UIMeta group=4 order=401 }}"
  type        = string
  default     = "altostrat-private-cloud"

  validation {
    condition     = startswith(var.private_cloud_name, "altostrat-")
    error_message = "private_cloud_name must start with 'altostrat-'."
  }
}

variable "management_cidr" {
  description = "CIDR block reserved for the VMware Engine management cluster (e.g. '10.11.0.0/23'). Cannot be changed after private cloud creation. Must not overlap with the peer VPC or edge services CIDR. {{UIMeta group=4 order=402 }}"
  type        = string
  default     = "10.11.0.0/23"
}

variable "node_type_id" {
  description = "VMware Engine node type for the management cluster (e.g. 'standard-72'). Availability is zone-dependent. {{UIMeta group=4 order=403 }}"
  type        = string
  default     = "standard-72"
}

variable "node_count" {
  description = "Number of nodes in the management cluster. Minimum is 3 for production workloads. {{UIMeta group=4 order=404 }}"
  type        = number
  default     = 3

  validation {
    condition     = var.node_count >= 3
    error_message = "node_count must be at least 3."
  }
}

// SECTION 5: Network Peering

variable "network_peering_name" {
  description = "Name of the VPC Network Peering between the VMware Engine network and the peer VPC. {{UIMeta group=5 order=501 }}"
  type        = string
  default     = "altostrat-vpc-peering"
}

variable "peer_vpc_name" {
  description = "Name of the GCP VPC network to peer with the VMware Engine network (the vmaas network, e.g. 'default'). {{UIMeta group=5 order=502 }}"
  type        = string
  default     = "default"
}

// SECTION 6: Network Policy

variable "network_policy_name" {
  description = "Name of the VMware Engine Network Policy that controls internet and external IP access. {{UIMeta group=6 order=601 }}"
  type        = string
  default     = "altostrat-gcve-edge"
}

variable "edge_services_cidr" {
  description = "CIDR block for VMware Engine edge services (internet ingress/egress, e.g. '10.11.2.0/26'). Must not overlap with management_cidr or the peer VPC subnets. {{UIMeta group=6 order=602 }}"
  type        = string
  default     = "10.11.2.0/26"
}

variable "enable_internet_access" {
  description = "Set to true (default) to enable internet access from VMware Engine workload VMs via the edge services CIDR. {{UIMeta group=6 order=603 }}"
  type        = bool
  default     = true
}

variable "enable_external_ip" {
  description = "Set to true (default) to enable external IP address allocation for VMware Engine workload VMs. {{UIMeta group=6 order=604 }}"
  type        = bool
  default     = true
}

// SECTION 7: Firewall Rules

variable "create_default_firewall_rules" {
  description = "Set to true (default) to create the four Google-default firewall rules (allow-internal, allow-ssh, allow-rdp, allow-icmp) on the peer VPC. Set to false if these rules already exist on the target network. {{UIMeta group=7 order=701 }}"
  type        = bool
  default     = true
}

variable "internal_traffic_cidr" {
  description = "CIDR block used as the source range for the allow-internal firewall rule. Matches the default VPC auto-mode subnet range. Override if using a custom-mode VPC. {{UIMeta group=7 order=702 }}"
  type        = string
  default     = "10.128.0.0/9"
}
