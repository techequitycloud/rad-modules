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
  description = "Enter list of users requiring trusted project privileges. {{UIMeta group=1 order=201 }}"
  type        = list(string)
  default     = []
}

variable "enable_services" {
  description = "Enable project APIs. {{UIMeta group=0 order=202 }}"
  type        = bool
  default     = true
}

variable "enable_quota_overrides" {
  description = "Enable GCP Compute Engine quota overrides. {{UIMeta group=0 order=203 }}"
  type        = bool
  default     = false
}

variable "quota_overrides" {
  description = "Map of Compute Engine quota metrics to their limit values for web app deployment (Cloud Run, Cloud SQL focused). {{UIMeta group=0 order=204 }}"
  type = map(object({
    limit  = number
    metric = string
  }))
  default = {
    # Storage & Images - Minimal for Cloud Run/SQL workloads
    "SNAPSHOTS" = {
      metric = "SNAPSHOTS"
      limit  = 50  # Reduced: Cloud SQL automated backups, occasional manual snapshots
    }
    "IMAGES" = {
      metric = "IMAGES"
      limit  = 20  # Reduced: Container images handled by Artifact Registry, not Compute Engine
    }
    "MACHINE_IMAGES" = {
      metric = "MACHINE_IMAGES"
      limit  = 10  # Reduced: Rarely needed for serverless workloads
    }

    # Networking - Core infrastructure
    "NETWORKS" = {
      metric = "NETWORKS"
      limit  = 3  # Reduced: Typically dev, staging, prod VPCs
    }
    "SUBNETWORKS" = {
      metric = "SUBNETWORKS"
      limit  = 20  # Reduced: Few subnets per VPC (per region/service)
    }
    "FIREWALLS" = {
      metric = "FIREWALLS"
      limit  = 50  # Reduced: Simplified rules for Cloud Run, Cloud SQL access
    }
    "ROUTES" = {
      metric = "ROUTES"
      limit  = 100  # Reduced: Standard routing sufficient
    }

    # IP Addresses - Conservative limits
    "STATIC_ADDRESSES" = {
      metric = "STATIC_ADDRESSES"
      limit  = 5  # Reduced: Cloud Run uses dynamic IPs, few static IPs needed
    }
    "IN_USE_ADDRESSES" = {
      metric = "IN_USE_ADDRESSES"
      limit  = 10  # Reduced: Limited IP allocation needs
    }
    "GLOBAL_INTERNAL_ADDRESSES" = {
      metric = "GLOBAL_INTERNAL_ADDRESSES"
      limit  = 100  # Reduced: Private Service Connect for Cloud SQL
    }
    "STATIC_BYOIP_ADDRESSES" = {
      metric = "STATIC_BYOIP_ADDRESSES"
      limit  = 0  # Disabled: Not needed for typical SMB web apps
    }

    # Load Balancing - Web application focused
    "FORWARDING_RULES" = {
      metric = "FORWARDING_RULES"
      limit  = 10  # Reduced: Few load balancers needed
    }
    "GLOBAL_EXTERNAL_MANAGED_FORWARDING_RULES" = {
      metric = "GLOBAL_EXTERNAL_MANAGED_FORWARDING_RULES"
      limit  = 10  # For external Application Load Balancers
    }
    "INTERNAL_TRAFFIC_DIRECTOR_FORWARDING_RULES" = {
      metric = "INTERNAL_TRAFFIC_DIRECTOR_FORWARDING_RULES"
      limit  = 5  # Reduced: Internal service mesh (if needed)
    }
    "BACKEND_SERVICES" = {
      metric = "BACKEND_SERVICES"
      limit  = 15  # Reduced: Cloud Run services as backends
    }
    "GLOBAL_EXTERNAL_MANAGED_BACKEND_SERVICES" = {
      metric = "GLOBAL_EXTERNAL_MANAGED_BACKEND_SERVICES"
      limit  = 15  # For Cloud Run backends
    }
    "GLOBAL_EXTERNAL_PROXY_LB_BACKEND_SERVICES" = {
      metric = "GLOBAL_EXTERNAL_PROXY_LB_BACKEND_SERVICES"
      limit  = 15  # For HTTPS/HTTP(S) load balancers
    }
    "GLOBAL_INTERNAL_MANAGED_BACKEND_SERVICES" = {
      metric = "GLOBAL_INTERNAL_MANAGED_BACKEND_SERVICES"
      limit  = 10  # Reduced: Internal backends
    }
    "GLOBAL_INTERNAL_TRAFFIC_DIRECTOR_BACKEND_SERVICES" = {
      metric = "GLOBAL_INTERNAL_TRAFFIC_DIRECTOR_BACKEND_SERVICES"
      limit  = 20  # Reduced: Service mesh backends
    }
    "BACKEND_BUCKETS" = {
      metric = "BACKEND_BUCKETS"
      limit  = 5  # For serving static content from Cloud Storage
    }

    # HTTP(S) Proxies & URL Maps
    "TARGET_HTTP_PROXIES" = {
      metric = "TARGET_HTTP_PROXIES"
      limit  = 5  # Reduced: Few HTTP load balancers
    }
    "TARGET_HTTPS_PROXIES" = {
      metric = "TARGET_HTTPS_PROXIES"
      limit  = 10  # HTTPS load balancers for web apps
    }
    "TARGET_SSL_PROXIES" = {
      metric = "TARGET_SSL_PROXIES"
      limit  = 5  # Reduced: SSL proxy load balancers
    }
    "TARGET_TCP_PROXIES" = {
      metric = "TARGET_TCP_PROXIES"
      limit  = 5  # Reduced: TCP proxy load balancers
    }
    "URL_MAPS" = {
      metric = "URL_MAPS"
      limit  = 10  # URL routing configurations
    }

    # SSL/TLS Certificates
    "SSL_CERTIFICATES" = {
      metric = "SSL_CERTIFICATES"
      limit  = 20  # Managed certs for multiple domains/environments
    }
    "SSL_POLICIES" = {
      metric = "SSL_POLICIES"
      limit  = 5  # Reduced: Few SSL policy configurations
    }

    # Health Checks
    "HEALTH_CHECKS" = {
      metric = "HEALTH_CHECKS"
      limit  = 20  # Reduced: Health checks for Cloud Run services
    }

    # Security
    "SECURITY_POLICIES" = {
      metric = "SECURITY_POLICIES"
      limit  = 5  # Reduced: Cloud Armor policies for DDoS/WAF
    }
    "SECURITY_POLICY_RULES" = {
      metric = "SECURITY_POLICY_RULES"
      limit  = 50  # Reduced: Rules per security policy
    }
    "SECURITY_POLICY_CEVAL_RULES" = {
      metric = "SECURITY_POLICY_CEVAL_RULES"
      limit  = 10  # Reduced: Custom expression rules
    }
    "NETWORK_FIREWALL_POLICIES" = {
      metric = "NETWORK_FIREWALL_POLICIES"
      limit  = 5  # Reduced: Hierarchical firewall policies
    }

    # Network Endpoint Groups (for Cloud Run)
    "NETWORK_ENDPOINT_GROUPS" = {
      metric = "NETWORK_ENDPOINT_GROUPS"
      limit  = 30  # Serverless NEGs for Cloud Run services
    }

    # Compute Resources - Minimal for serverless
    "CPUS_ALL_REGIONS" = {
      metric = "CPUS_ALL_REGIONS"
      limit  = 16  # Reduced: Minimal VMs (bastion, CI/CD, etc.)
    }
    "GPUS_ALL_REGIONS" = {
      metric = "GPUS_ALL_REGIONS"
      limit  = 0  # Disabled: Not needed for typical web apps
    }
    "INSTANCE_TEMPLATES" = {
      metric = "INSTANCE_TEMPLATES"
      limit  = 10  # Reduced: Few templates if using managed instance groups
    }
    "TARGET_INSTANCES" = {
      metric = "TARGET_INSTANCES"
      limit  = 5  # Reduced: Rarely used with Cloud Run
    }
    "TARGET_POOLS" = {
      metric = "TARGET_POOLS"
      limit  = 5  # Reduced: Legacy load balancing
    }

    # VPN & Interconnect - Minimal hybrid connectivity
    "VPN_GATEWAYS" = {
      metric = "VPN_GATEWAYS"
      limit  = 2  # HA VPN for hybrid connectivity
    }
    "TARGET_VPN_GATEWAYS" = {
      metric = "TARGET_VPN_GATEWAYS"
      limit  = 2  # Legacy VPN
    }
    "VPN_TUNNELS" = {
      metric = "VPN_TUNNELS"
      limit  = 8  # Tunnels for HA VPN
    }
    "EXTERNAL_VPN_GATEWAYS" = {
      metric = "EXTERNAL_VPN_GATEWAYS"
      limit  = 2  # External VPN gateway definitions
    }
    "INTERCONNECTS" = {
      metric = "INTERCONNECTS"
      limit  = 0  # Disabled: Dedicated Interconnect not needed for SMB
    }

    # Routing
    "ROUTERS" = {
      metric = "ROUTERS"
      limit  = 6  # Cloud Routers for VPN/NAT
    }

    # Advanced Features - Disabled/Minimal
    "PACKET_MIRRORINGS" = {
      metric = "PACKET_MIRRORINGS"
      limit  = 2  # Reduced: Rarely needed
    }
    "PUBLIC_ADVERTISED_PREFIXES" = {
      metric = "PUBLIC_ADVERTISED_PREFIXES"
      limit  = 0  # Disabled: BYOIP not needed
    }
    "PUBLIC_DELEGATED_PREFIXES" = {
      metric = "PUBLIC_DELEGATED_PREFIXES"
      limit  = 0  # Disabled: BYOIP not needed
    }

    # Shared VPC (if using multi-project setup)
    "XPN_SERVICE_PROJECTS" = {
      metric = "XPN_SERVICE_PROJECTS"
      limit  = 20  # Reduced: Service projects in Shared VPC
    }
  }
}
