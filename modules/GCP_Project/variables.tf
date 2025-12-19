# Copyright 2024 (c) Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# GROUP 1: Deployment 

variable "module_description" {
  description = "The description of the module. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = "This module creates a foundational Google Cloud project, enables the necessary APIs for budget configuration, and serves as the basis for deploying other application modules."
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = []
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP", "Cloud IAM"]
}

variable "credit_cost" {
  description = "Specify the module cost {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 50
}

variable "require_credit_purchases" {
  description = "Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=104 }}"
  type        = bool
  default     = false
}

variable "enable_purge" {
  description = "Set to true to enable the ability to purge this module. {{UIMeta group=0 order=105 }}"
  type        = bool
  default     = false
}

variable "public_access" {
description = "Set to true to enable the module to be available to all platform users. {{UIMeta group=0 order=106 }}"
type = bool
default = false
}

variable "deployment_id" {
  description = "Unique ID suffix for resources. Leave blank to generate random ID."
  type        = string
  default     = null
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. {{UIMeta group=0 order=102 }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "folder_id" {
  description = "RAD UI folder ID. {{UIMeta group=0 order=104 }}"
  type        = string
  default     = "158723424265"
}

variable "module_folder_id" {
  description = "Specify the RAD folder ID. {{UIMeta group=0 order=104 }}"
  type        = string
  default     = "785897258084"
}

variable "organization_id" {
  description = "Organization ID where GCP Resources need to be deployed. {{UIMeta group=0 order=1 }}"
  type        = string
  default     = ""
}

variable "billing_account_id" {
  description = "Billing Account associated with GCP resources. {{UIMeta group=0 order=0 }}"
  type        = string
}

# GROUP 2: Project

variable "project_id_prefix" {
  description = "Enter the prefix of the project ID. {{UIMeta group=1 order=200 }}"
  type        = string
}

variable "trusted_users" {
  description = "List of users with project trusted privileges. {{UIMeta group=0 order=201 }}"
  type        = list(string)
  default     = []
}

variable "enable_services" {
  description = "Enable project APIs. {{UIMeta group=1 order=202 }}"
  type        = bool
  default     = false
}

variable "enable_quota_overrides" {
  description = "Enable GCP Compute Engine quota overrides. {{UIMeta group=1 order=203 }}"
  type        = bool
  default     = false
}

variable "quota_overrides" {
  description = "Map of Compute Engine quota metrics to their limit values. {{UIMeta group=1 order=204 }}"
  type = map(object({
    limit  = number
    metric = string
  }))
  default = {
    "SNAPSHOTS" = {
      metric = "SNAPSHOTS"
      limit  = 1000
    }
    "NETWORKS" = {
      metric = "NETWORKS"
      limit  = 5
    }
    "FIREWALLS" = {
      metric = "FIREWALLS"
      limit  = 100
    }
    "IMAGES" = {
      metric = "IMAGES"
      limit  = 100
    }
    "STATIC_ADDRESSES" = {
      metric = "STATIC_ADDRESSES"
      limit  = 8
    }
    "ROUTES" = {
      metric = "ROUTES"
      limit  = 200
    }
    "FORWARDING_RULES" = {
      metric = "FORWARDING_RULES"
      limit  = 15
    }
    "TARGET_POOLS" = {
      metric = "TARGET_POOLS"
      limit  = 50
    }
    "HEALTH_CHECKS" = {
      metric = "HEALTH_CHECKS"
      limit  = 75
    }
    "IN_USE_ADDRESSES" = {
      metric = "IN_USE_ADDRESSES"
      limit  = 8
    }
    "TARGET_INSTANCES" = {
      metric = "TARGET_INSTANCES"
      limit  = 50
    }
    "TARGET_HTTP_PROXIES" = {
      metric = "TARGET_HTTP_PROXIES"
      limit  = 10
    }
    "URL_MAPS" = {
      metric = "URL_MAPS"
      limit  = 10
    }
    "BACKEND_SERVICES" = {
      metric = "BACKEND_SERVICES"
      limit  = 50
    }
    "INSTANCE_TEMPLATES" = {
      metric = "INSTANCE_TEMPLATES"
      limit  = 100
    }
    "TARGET_VPN_GATEWAYS" = {
      metric = "TARGET_VPN_GATEWAYS"
      limit  = 5
    }
    "VPN_TUNNELS" = {
      metric = "VPN_TUNNELS"
      limit  = 10
    }
    "BACKEND_BUCKETS" = {
      metric = "BACKEND_BUCKETS"
      limit  = 3
    }
    "ROUTERS" = {
      metric = "ROUTERS"
      limit  = 10
    }
    "TARGET_SSL_PROXIES" = {
      metric = "TARGET_SSL_PROXIES"
      limit  = 10
    }
    "TARGET_HTTPS_PROXIES" = {
      metric = "TARGET_HTTPS_PROXIES"
      limit  = 10
    }
    "SSL_CERTIFICATES" = {
      metric = "SSL_CERTIFICATES"
      limit  = 10
    }
    "SUBNETWORKS" = {
      metric = "SUBNETWORKS"
      limit  = 100
    }
    "TARGET_TCP_PROXIES" = {
      metric = "TARGET_TCP_PROXIES"
      limit  = 10
    }
    "CPUS_ALL_REGIONS" = {
      metric = "CPUS_ALL_REGIONS"
      limit  = 32
    }
    "SECURITY_POLICIES" = {
      metric = "SECURITY_POLICIES"
      limit  = 10
    }
    "SECURITY_POLICY_RULES" = {
      metric = "SECURITY_POLICY_RULES"
      limit  = 100
    }
    "XPN_SERVICE_PROJECTS" = {
      metric = "XPN_SERVICE_PROJECTS"
      limit  = 1000
    }
    "PACKET_MIRRORINGS" = {
      metric = "PACKET_MIRRORINGS"
      limit  = 20
    }
    "NETWORK_ENDPOINT_GROUPS" = {
      metric = "NETWORK_ENDPOINT_GROUPS"
      limit  = 100
    }
    "INTERCONNECTS" = {
      metric = "INTERCONNECTS"
      limit  = 6
    }
    "SSL_POLICIES" = {
      metric = "SSL_POLICIES"
      limit  = 10
    }
    "GLOBAL_INTERNAL_ADDRESSES" = {
      metric = "GLOBAL_INTERNAL_ADDRESSES"
      limit  = 5000
    }
    "VPN_GATEWAYS" = {
      metric = "VPN_GATEWAYS"
      limit  = 5
    }
    "MACHINE_IMAGES" = {
      metric = "MACHINE_IMAGES"
      limit  = 100
    }
    "SECURITY_POLICY_CEVAL_RULES" = {
      metric = "SECURITY_POLICY_CEVAL_RULES"
      limit  = 20
    }
    "GPUS_ALL_REGIONS" = {
      metric = "GPUS_ALL_REGIONS"
      limit  = 0
    }
    "EXTERNAL_VPN_GATEWAYS" = {
      metric = "EXTERNAL_VPN_GATEWAYS"
      limit  = 5
    }
    "PUBLIC_ADVERTISED_PREFIXES" = {
      metric = "PUBLIC_ADVERTISED_PREFIXES"
      limit  = 1
    }
    "PUBLIC_DELEGATED_PREFIXES" = {
      metric = "PUBLIC_DELEGATED_PREFIXES"
      limit  = 10
    }
    "STATIC_BYOIP_ADDRESSES" = {
      metric = "STATIC_BYOIP_ADDRESSES"
      limit  = 128
    }
    "NETWORK_FIREWALL_POLICIES" = {
      metric = "NETWORK_FIREWALL_POLICIES"
      limit  = 10
    }
    "INTERNAL_TRAFFIC_DIRECTOR_FORWARDING_RULES" = {
      metric = "INTERNAL_TRAFFIC_DIRECTOR_FORWARDING_RULES"
      limit  = 15
    }
    "GLOBAL_EXTERNAL_MANAGED_FORWARDING_RULES" = {
      metric = "GLOBAL_EXTERNAL_MANAGED_FORWARDING_RULES"
      limit  = 15
    }
    "GLOBAL_INTERNAL_MANAGED_BACKEND_SERVICES" = {
      metric = "GLOBAL_INTERNAL_MANAGED_BACKEND_SERVICES"
      limit  = 50
    }
    "GLOBAL_EXTERNAL_MANAGED_BACKEND_SERVICES" = {
      metric = "GLOBAL_EXTERNAL_MANAGED_BACKEND_SERVICES"
      limit  = 50
    }
    "GLOBAL_EXTERNAL_PROXY_LB_BACKEND_SERVICES" = {
      metric = "GLOBAL_EXTERNAL_PROXY_LB_BACKEND_SERVICES"
      limit  = 50
    }
    "GLOBAL_INTERNAL_TRAFFIC_DIRECTOR_BACKEND_SERVICES" = {
      metric = "GLOBAL_INTERNAL_TRAFFIC_DIRECTOR_BACKEND_SERVICES"
      limit  = 250
    }
  }
}
