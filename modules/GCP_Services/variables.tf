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
  default     = "This module configures foundational Google Cloud infrastructure services for modern application development (vibe coding), including VPC networking, Cloud SQL databases, Redis cache, and IAM service accounts. It prepares your project with the necessary infrastructure for deploying containerized applications and serverless workloads via Cloud Run and Cloud Build."
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=1 }}"
  type        = list(string)
  default     = ["GCP_Project"]
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=2 }}"
  type        = list(string)
  default     = ["VPC Networking", "Cloud SQL", "Redis Cache", "Cloud IAM", "NFS Storage"]
}

variable "credit_cost" {
  description = "Specify the module cost {{UIMeta group=0 order=3 }}"
  type        = number
  default     = 100
}

variable "require_credit_purchases" {
  description = "Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=4 }}"
  type        = bool
  default     = false
}

variable "enable_purge" {
  description = "Set to true to enable the ability to purge this module. {{UIMeta group=0 order=5 }}"
  type        = bool
  default     = true
}

variable "public_access" {
  description = "Set to true to enable the module to be available to all platform users. {{UIMeta group=0 order=6 }}"
  type = bool
  default = true
}

variable "deployment_id" {
  description = "Unique ID suffix for resources.  Leave blank to generate random ID. {{UIMeta group=0 order=10 }}"
  type        = string
  default     = null
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=0 order=11 }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of trusted users with limited Google Cloud project admin privileges. (e.g. `username@abc.com`). {{UIMeta group=0 order=12 }}"
  type        = list(string)
  default     = []
}

variable "enable_services" {
  description = "Enable project APIs. {{UIMeta group=0 order=20 }}"
  type        = bool
  default     = true
}

variable "network_name" {
  description = "Name to be assigned to the VPC network. {{UIMeta group=0 order=30 }}"
  type        = string
  default     = "vpc-network"
}

variable "gce_subnet_cidr_range" {
  description = "List of CIDR ranges for GCE subnets, one per availability region. {{UIMeta group=0 order=31 }}"
  type        = list(string)
  default     = [
    "10.0.0.0/24",
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  validation {
    condition     = length(var.gce_subnet_cidr_range) > 0
    error_message = "At least one CIDR range must be specified for GCE subnets."
  }

  validation {
    condition = alltrue([
      for cidr in var.gce_subnet_cidr_range :
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))
    ])
    error_message = "All CIDR ranges must be in valid format (e.g., 10.0.0.0/24)."
  }
}

################################################################################
# GROUP 1: Project Configuration (User-accessible)
################################################################################


variable "agent_service_account" {
  description = "If deploying into an existing GCP project outside of the RAD platform, enter a RAD GCP project agent service account, e.g. rad-agent@gcp-project.sr65.iam.gserviceaccount.com, and grant this service account IAM Owner role in the target Google Cloud project. Leave this field blank if deploying into a target project on the RAD platform. {{UIMeta group=1 order=0 updatesafe }}"
  type        = string
  default     = null
}

variable "existing_project_id" {
  description = "Select an existing project on the RAD platform or enter the project ID of an external GCP project. You must grant Owner role to the RAD GCP Project agent service account when deploying into an external project. {{UIMeta group=2 order=1 }}"
  type        = string
}

variable "availability_regions" {
  description = "The one or two regions where resources should be configured. The deployment might fail if sufficient resources not available in chosen region. {{UIMeta group=2 order=2 }}"
  type        = list(string)
  default     = ["us-central1"]

  validation {
    condition     = length(var.availability_regions) > 0
    error_message = "At least one availability region must be specified."
  }
}

################################################################################
# GROUP 2: Service Selection (User-accessible)
################################################################################

variable "create_postgres" {
  description = "Select to create PostgreSQL database instance. {{UIMeta group=4 order=0 }}"
  type        = bool
  default     = true
}

variable "create_mysql" {
  description = "Select to create MySQL database instance. {{UIMeta group=4 order=1 }}"
  type        = bool
  default     = false
}

variable "create_redis" {
  description = "Select to create Redis cache instance for application caching and session storage. {{UIMeta group=4 order=2 }}"
  type        = bool
  default     = false
}

variable "create_network_filesystem" {
  description = "Select to create NFS server using Compute Engine instances for shared file storage. {{UIMeta group=4 order=3 }}"
  type        = bool
  default     = false
}

################################################################################
# GROUP 3: Database Configuration (User-accessible)
################################################################################

variable "postgres_database_availability_type" {
  description = "The availability type of the PostgreSQL instance. ZONAL is cost-effective for development; REGIONAL provides high availability for production. {{UIMeta group=4 order=0 options=ZONAL,REGIONAL }}"
  type        = string
  default     = "ZONAL"
}

variable "mysql_database_availability_type" {
  description = "The availability type of the MySQL instance. ZONAL is cost-effective for development; REGIONAL provides high availability for production. {{UIMeta group=4 order=1 options=ZONAL,REGIONAL }}"
  type        = string
  default     = "ZONAL"
}

################################################################################
# GROUP 4: Cache Configuration (User-accessible)
################################################################################

variable "redis_tier" {
  description = "The service tier of the Redis instance. BASIC provides a standalone instance; STANDARD_HA provides high availability. {{UIMeta group=5 order=0 options=BASIC,STANDARD_HA }}"
  type        = string
  default     = "BASIC"
}

variable "redis_memory_size_gb" {
  description = "Memory size in GB for the Redis instance. {{UIMeta group=5 order=1 }}"
  type        = number
  default     = 1

  validation {
    condition     = var.redis_memory_size_gb >= 1 && var.redis_memory_size_gb <= 300
    error_message = "Redis memory size must be between 1 and 300 GB."
  }
}

################################################################################
# GROUP 0: Advanced Configuration (Admin-only) - Database
################################################################################

variable "postgres_database_version" {
  description = "PostgreSQL database version to use. {{UIMeta group=0 order=40 options=POSTGRES_16,POSTGRES_15,POSTGRES_14 }}"
  type        = string
  default     = "POSTGRES_16"
}

variable "postgres_tier" {
  description = "The machine type to use for PostgreSQL. Supports shared-core and custom machine types such as `db-custom-2-13312`. {{UIMeta group=0 order=41 }}"
  type        = string
  default     = "db-custom-1-3840"
}

variable "mysql_database_version" {
  description = "MySQL database version to use. {{UIMeta group=0 order=42 options=MYSQL_8_0,MYSQL_5_7 }}"
  type        = string
  default     = "MYSQL_8_0"
}

variable "mysql_tier" {
  description = "The machine type to use for MySQL. Supports shared-core and custom machine types such as `db-custom-2-13312`. {{UIMeta group=0 order=43 }}"
  type        = string
  default     = "db-custom-1-3840"
}

################################################################################
# GROUP 0: Advanced Configuration (Admin-only) - Cache
################################################################################

variable "redis_version" {
  description = "Redis version to use. {{UIMeta group=0 order=50 options=REDIS_7_2,REDIS_7_0,REDIS_6_X }}"
  type        = string
  default     = "REDIS_7_2"
}

variable "redis_connect_mode" {
  description = "Network connection mode for Redis. {{UIMeta group=0 order=51 options=DIRECT_PEERING,PRIVATE_SERVICE_ACCESS }}"
  type        = string
  default     = "DIRECT_PEERING"
}

################################################################################
# GROUP 0: Advanced Configuration (Admin-only) - NFS
################################################################################

variable "network_filesystem_machine" {
  description = "NFS server machine type. {{UIMeta group=0 order=90 }}"
  type        = string
  default     = "e2-small"
}

variable "network_filesystem_capacity" {
  description = "Size of NFS server disks in GB. {{UIMeta group=0 order=91 }}"
  type        = number
  default     = 10
}
