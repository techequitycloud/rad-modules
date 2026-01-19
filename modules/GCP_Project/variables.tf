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

################################################################################
# GROUP 0: Module Administration (Admin-only)
################################################################################

variable "module_description" {
  description = "The description of the module. {{UIMeta group=0 order=0 }}"
  type        = string
  default     = "This module creates a foundational Google Cloud project, enables the necessary APIs for budget configuration, and serves as the basis for deploying other application modules."
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=1 }}"
  type        = list(string)
  default     = []
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=2 }}"
  type        = list(string)
  default     = ["Cloud IAM", "Cloud Resource Manager", "Service Usage", "Cloud Billing"]
}

variable "credit_cost" {
  description = "Specify the module cost {{UIMeta group=0 order=3 }}"
  type        = number
  default     = 100
}

variable "require_credit_purchases" {
  description = "Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=4 }}"
  type        = bool
  default     = true
}

variable "enable_purge" {
  description = "Set to true to enable the ability to purge this module. {{UIMeta group=0 order=5 }}"
  type        = bool
  default     = false
}

variable "public_access" {
  description = "Set to true to enable the module to be available to all platform users. {{UIMeta group=0 order=6 }}"
  type        = bool
  default     = true
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. {{UIMeta group=0 order=10 }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "folder_id" {
  description = "RAD UI folder ID. {{UIMeta group=0 order=11 }}"
  type        = string
  default     = "158723424265"
}

variable "module_folder_id" {
  description = "Specify the RAD folder ID. {{UIMeta group=0 order=12 }}"
  type        = string
  default     = "898880854637"
}

variable "organization_id" {
  description = "Organization ID where GCP Resources need to be deployed. {{UIMeta group=0 order=13 }}"
  type        = string
  default     = "142439919440"
}

variable "billing_account_id" {
  description = "Billing Account associated with GCP resources. {{UIMeta group=0 order=14 }}"
  type        = string
}

variable "enable_services" {
  description = "Enable project APIs. {{UIMeta group=0 order=20 }}"
  type        = bool
  default     = true
}

variable "enable_quota_overrides" {
  description = "Enable GCP quota overrides for enhanced security and cost control. {{UIMeta group=0 order=21 }}"
  type        = bool
  default     = false
}

################################################################################
# GROUP 1: Project Configuration (User-accessible)
################################################################################

variable "project_id_prefix" {
  description = "Enter the prefix of the project ID. A random suffix will be appended. {{UIMeta group=1 order=100 }}"
  type        = string
}

variable "deployment_id" {
  description = "Unique ID suffix for resources. Leave blank to generate random ID. {{UIMeta group=1 order=101 }}"
  type        = string
  default     = null
}

variable "trusted_users" {
  description = "List of user email addresses requiring DevOps privileges (Editor, Cloud Run Admin, Cloud SQL Admin, etc.). {{UIMeta group=1 order=110 }}"
  type        = list(string)
  default     = []
}

variable "billing_budget_amount" {
  description = "Monthly budget limit for the project in USD. Alerts sent at 50%, 80%, and 100%. {{UIMeta group=1 order=120 }}"
  type        = number
  default     = 10
}

variable "billing_budget_alert_emails" {
  description = "List of email addresses to receive budget alerts. {{UIMeta group=1 order=121 }}"
  type        = list(string)
  default     = []
}

################################################################################
# GROUP 2: Compute Engine Quotas (Admin-only)
################################################################################

variable "quota_overrides" {
  description = "Map of Compute Engine quota metrics to their limit values. These quotas provide security and cost protection. {{UIMeta group=0 order=200 }}"
  type = map(object({
    limit  = number
    metric = string
  }))
  default = {
    # Storage & Images - Minimal for Cloud Run/SQL workloads
    "SNAPSHOTS" = {
      metric = "SNAPSHOTS"
      limit  = 50 # Cloud SQL automated backups, occasional manual snapshots
    }
    "IMAGES" = {
      metric = "IMAGES"
      limit  = 20 # Container images handled by Artifact Registry
    }
    "MACHINE_IMAGES" = {
      metric = "MACHINE_IMAGES"
      limit  = 10 # Rarely needed for serverless workloads
    }

    # Networking - Core infrastructure
    "NETWORKS" = {
      metric = "NETWORKS"
      limit  = 3 # Typically dev, staging, prod VPCs
    }
    "SUBNETWORKS" = {
      metric = "SUBNETWORKS"
      limit  = 20 # Few subnets per VPC (per region/service)
    }
    "FIREWALLS" = {
      metric = "FIREWALLS"
      limit  = 50 # Simplified rules for Cloud Run, Cloud SQL access
    }
    "ROUTES" = {
      metric = "ROUTES"
      limit  = 100 # Standard routing sufficient
    }

    # IP Addresses - Conservative limits
    "STATIC_ADDRESSES" = {
      metric = "STATIC_ADDRESSES"
      limit  = 5 # Cloud Run uses dynamic IPs, few static IPs needed
    }
    "IN_USE_ADDRESSES" = {
      metric = "IN_USE_ADDRESSES"
      limit  = 10 # Limited IP allocation needs
    }
    "GLOBAL_INTERNAL_ADDRESSES" = {
      metric = "GLOBAL_INTERNAL_ADDRESSES"
      limit  = 100 # Private Service Connect for Cloud SQL
    }
    "STATIC_BYOIP_ADDRESSES" = {
      metric = "STATIC_BYOIP_ADDRESSES"
      limit  = 0 # Not needed for typical SMB web apps
    }

    # Load Balancing - Web application focused
    "FORWARDING_RULES" = {
      metric = "FORWARDING_RULES"
      limit  = 10 # Few load balancers needed
    }
    "GLOBAL_EXTERNAL_MANAGED_FORWARDING_RULES" = {
      metric = "GLOBAL_EXTERNAL_MANAGED_FORWARDING_RULES"
      limit  = 10 # External Application Load Balancers
    }
    "INTERNAL_TRAFFIC_DIRECTOR_FORWARDING_RULES" = {
      metric = "INTERNAL_TRAFFIC_DIRECTOR_FORWARDING_RULES"
      limit  = 5 # Internal service mesh
    }
    "BACKEND_SERVICES" = {
      metric = "BACKEND_SERVICES"
      limit  = 15 # Cloud Run services as backends
    }
    "GLOBAL_EXTERNAL_MANAGED_BACKEND_SERVICES" = {
      metric = "GLOBAL_EXTERNAL_MANAGED_BACKEND_SERVICES"
      limit  = 15 # Cloud Run backends
    }
    "GLOBAL_EXTERNAL_PROXY_LB_BACKEND_SERVICES" = {
      metric = "GLOBAL_EXTERNAL_PROXY_LB_BACKEND_SERVICES"
      limit  = 15 # HTTPS/HTTP(S) load balancers
    }
    "GLOBAL_INTERNAL_MANAGED_BACKEND_SERVICES" = {
      metric = "GLOBAL_INTERNAL_MANAGED_BACKEND_SERVICES"
      limit  = 10 # Internal backends
    }
    "GLOBAL_INTERNAL_TRAFFIC_DIRECTOR_BACKEND_SERVICES" = {
      metric = "GLOBAL_INTERNAL_TRAFFIC_DIRECTOR_BACKEND_SERVICES"
      limit  = 20 # Service mesh backends
    }
    "BACKEND_BUCKETS" = {
      metric = "BACKEND_BUCKETS"
      limit  = 5 # Serving static content from Cloud Storage
    }

    # HTTP(S) Proxies & URL Maps
    "TARGET_HTTP_PROXIES" = {
      metric = "TARGET_HTTP_PROXIES"
      limit  = 5 # HTTP load balancers
    }
    "TARGET_HTTPS_PROXIES" = {
      metric = "TARGET_HTTPS_PROXIES"
      limit  = 10 # HTTPS load balancers for web apps
    }
    "TARGET_SSL_PROXIES" = {
      metric = "TARGET_SSL_PROXIES"
      limit  = 5 # SSL proxy load balancers
    }
    "TARGET_TCP_PROXIES" = {
      metric = "TARGET_TCP_PROXIES"
      limit  = 5 # TCP proxy load balancers
    }
    "URL_MAPS" = {
      metric = "URL_MAPS"
      limit  = 10 # URL routing configurations
    }

    # SSL/TLS Certificates
    "SSL_CERTIFICATES" = {
      metric = "SSL_CERTIFICATES"
      limit  = 20 # Managed certs for multiple domains/environments
    }
    "SSL_POLICIES" = {
      metric = "SSL_POLICIES"
      limit  = 5 # SSL policy configurations
    }

    # Health Checks
    "HEALTH_CHECKS" = {
      metric = "HEALTH_CHECKS"
      limit  = 20 # Health checks for Cloud Run services
    }

    # Security
    "SECURITY_POLICIES" = {
      metric = "SECURITY_POLICIES"
      limit  = 5 # Cloud Armor policies for DDoS/WAF
    }
    "SECURITY_POLICY_RULES" = {
      metric = "SECURITY_POLICY_RULES"
      limit  = 50 # Rules per security policy
    }
    "SECURITY_POLICY_CEVAL_RULES" = {
      metric = "SECURITY_POLICY_CEVAL_RULES"
      limit  = 10 # Custom expression rules
    }
    "NETWORK_FIREWALL_POLICIES" = {
      metric = "NETWORK_FIREWALL_POLICIES"
      limit  = 5 # Hierarchical firewall policies
    }

    # Network Endpoint Groups (for Cloud Run)
    "NETWORK_ENDPOINT_GROUPS" = {
      metric = "NETWORK_ENDPOINT_GROUPS"
      limit  = 30 # Serverless NEGs for Cloud Run services
    }

    # Compute Resources - Minimal for serverless
    "CPUS_ALL_REGIONS" = {
      metric = "CPUS_ALL_REGIONS"
      limit  = 16 # Minimal VMs (bastion, CI/CD)
    }
    "GPUS_ALL_REGIONS" = {
      metric = "GPUS_ALL_REGIONS"
      limit  = 0 # Not needed for typical web apps
    }
    "INSTANCE_TEMPLATES" = {
      metric = "INSTANCE_TEMPLATES"
      limit  = 10 # Few templates if using managed instance groups
    }
    "TARGET_INSTANCES" = {
      metric = "TARGET_INSTANCES"
      limit  = 5 # Rarely used with Cloud Run
    }
    "TARGET_POOLS" = {
      metric = "TARGET_POOLS"
      limit  = 5 # Legacy load balancing
    }

    # VPN & Interconnect - Minimal hybrid connectivity
    "VPN_GATEWAYS" = {
      metric = "VPN_GATEWAYS"
      limit  = 2 # HA VPN for hybrid connectivity
    }
    "TARGET_VPN_GATEWAYS" = {
      metric = "TARGET_VPN_GATEWAYS"
      limit  = 2 # Legacy VPN
    }
    "VPN_TUNNELS" = {
      metric = "VPN_TUNNELS"
      limit  = 8 # Tunnels for HA VPN
    }
    "EXTERNAL_VPN_GATEWAYS" = {
      metric = "EXTERNAL_VPN_GATEWAYS"
      limit  = 2 # External VPN gateway definitions
    }
    "INTERCONNECTS" = {
      metric = "INTERCONNECTS"
      limit  = 0 # Dedicated Interconnect not needed
    }

    # Routing
    "ROUTERS" = {
      metric = "ROUTERS"
      limit  = 6 # Cloud Routers for VPN/NAT
    }

    # Advanced Features
    "PACKET_MIRRORINGS" = {
      metric = "PACKET_MIRRORINGS"
      limit  = 2 # Packet mirroring for debugging
    }
    "PUBLIC_ADVERTISED_PREFIXES" = {
      metric = "PUBLIC_ADVERTISED_PREFIXES"
      limit  = 0 # BYOIP not needed
    }
    "PUBLIC_DELEGATED_PREFIXES" = {
      metric = "PUBLIC_DELEGATED_PREFIXES"
      limit  = 0 # BYOIP not needed
    }

    # Shared VPC
    "XPN_SERVICE_PROJECTS" = {
      metric = "XPN_SERVICE_PROJECTS"
      limit  = 20 # Service projects in Shared VPC
    }
  }
}

################################################################################
# GROUP 2: Cloud Run Quotas (Admin-only)
################################################################################

variable "run_quota_overrides" {
  description = "Cloud Run quota overrides to prevent runaway resource consumption. {{UIMeta group=0 order=210 }}"
  type = map(object({
    limit  = number
    metric = string
  }))
  default = {
    "SERVICES" = {
      metric = "Services"
      limit  = 100 # Maximum number of Cloud Run services
    }
    "REVISIONS" = {
      metric = "Revisions"
      limit  = 500 # Maximum revisions across all services
    }
  }
}

################################################################################
# GROUP 2: Cloud SQL Quotas (Admin-only)
################################################################################

variable "sql_quota_overrides" {
  description = "Cloud SQL quota overrides for security and cost control. {{UIMeta group=0 order=220 }}"
  type = map(object({
    limit  = number
    metric = string
  }))
  default = {
    "SQL_INSTANCES" = {
      metric = "Instances"
      limit  = 20 # Maximum SQL instances
    }
    "SQL_STORAGE_GB" = {
      metric = "StoragePerProject"
      limit  = 10000 # Total storage across all instances (GB)
    }
    "SQL_BACKUP_STORAGE_GB" = {
      metric = "BackupStoragePerProject"
      limit  = 20000 # Backup storage (GB)
    }
  }
}

################################################################################
# GROUP 2: Cloud Storage Quotas (Admin-only)
################################################################################

variable "storage_quota_overrides" {
  description = "Cloud Storage quota overrides for security and cost control. {{UIMeta group=0 order=230 }}"
  type = map(object({
    limit  = number
    metric = string
  }))
  default = {
    "BUCKETS" = {
      metric = "BucketsPerProject"
      limit  = 100 # Maximum storage buckets
    }
    "EGRESS_BANDWIDTH_GB" = {
      metric = "EgressBandwidthPerDay"
      limit  = 1000 # Daily egress bandwidth (GB)
    }
  }
}

################################################################################
# GROUP 2: Secret Manager Quotas (Admin-only)
################################################################################

variable "secretmanager_quota_overrides" {
  description = "Secret Manager quota overrides for security. {{UIMeta group=0 order=240 }}"
  type = map(object({
    limit  = number
    metric = string
  }))
  default = {
    "SECRETS" = {
      metric = "Secrets"
      limit  = 500 # Maximum number of secrets
    }
    "SECRET_VERSIONS" = {
      metric = "SecretVersions"
      limit  = 5000 # Maximum secret versions across all secrets
    }
    "SECRET_ACCESS_REQUESTS" = {
      metric = "AccessRequestsPerMinute"
      limit  = 60000 # Rate limit on secret access
    }
  }
}

################################################################################
# GROUP 2: Cloud Build Quotas (Admin-only)
################################################################################

variable "cloudbuild_quota_overrides" {
  description = "Cloud Build quota overrides to control CI/CD resource usage. {{UIMeta group=0 order=250 }}"
  type = map(object({
    limit  = number
    metric = string
  }))
  default = {
    "CONCURRENT_BUILDS" = {
      metric = "ConcurrentBuilds"
      limit  = 10 # Maximum concurrent builds
    }
    "BUILD_TIME_MINUTES" = {
      metric = "BuildTimePerDay"
      limit  = 1440 # Total build minutes per day (24 hours)
    }
  }
}

################################################################################
# GROUP 2: Artifact Registry Quotas (Admin-only)
################################################################################

variable "artifactregistry_quota_overrides" {
  description = "Artifact Registry quota overrides for container and artifact storage. {{UIMeta group=0 order=260 }}"
  type = map(object({
    limit  = number
    metric = string
  }))
  default = {
    "REPOSITORIES" = {
      metric = "Repositories"
      limit  = 50 # Maximum number of repositories
    }
    "STORAGE_GB" = {
      metric = "StoragePerProject"
      limit  = 500 # Total storage for artifacts (GB)
    }
  }
}

################################################################################
# GROUP 2: Pub/Sub Quotas (Admin-only)
################################################################################

variable "pubsub_quota_overrides" {
  description = "Pub/Sub quota overrides for messaging and event-driven architectures. {{UIMeta group=0 order=270 }}"
  type = map(object({
    limit  = number
    metric = string
  }))
  default = {
    "TOPICS" = {
      metric = "Topics"
      limit  = 1000 # Maximum number of topics
    }
    "SUBSCRIPTIONS" = {
      metric = "Subscriptions"
      limit  = 1000 # Maximum number of subscriptions
    }
    "THROUGHPUT_MB" = {
      metric = "ThroughputPerMinute"
      limit  = 1000 # Throughput limit (MB/min)
    }
  }
}
