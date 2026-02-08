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
# SECTION 0: Module Configuration (Admin-only)
################################################################################

variable "module_description" {
  description = "The description of the module. {{UIMeta group=0 order=0 }}"
  type        = string
  default     = "This module configures foundational Google Cloud infrastructure services for modern application development (vibe coding), including VPC networking, Cloud SQL databases, Redis cache, and IAM service accounts. It prepares your project with the necessary infrastructure for deploying containerized applications and serverless workloads via Cloud Run and Cloud Build."
}

variable "module_documentation" {
  description = "The URL to the module documentation. {{UIMeta group=0 order=1 }}"
  type        = string
  default     = "https://docs.techequity.cloud/docs/applications/gcp-services"
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=2 }}"
  type        = list(string)
  default     = ["GCP_Project"]
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=3 }}"
  type        = list(string)
  default     = ["VPC Networking", "Cloud SQL", "Redis Cache", "Cloud IAM", "NFS Storage"]
}

variable "credit_cost" {
  description = "Specify the module cost {{UIMeta group=0 order=4 }}"
  type        = number
  default     = 100
}

variable "require_credit_purchases" {
  description = "Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=5 }}"
  type        = bool
  default     = false
}

variable "enable_purge" {
  description = "Set to true to enable the ability to purge this module. {{UIMeta group=0 order=6 }}"
  type        = bool
  default     = true
}

variable "deployment_id" {
  description = "Unique ID suffix for resources.  Leave blank to generate random ID. {{UIMeta group=0 order=7 }}"
  type        = string
  default     = null
}

variable "public_access" {
  description = "Set to true to enable the module to be available to all platform users. {{UIMeta group=0 order=8 }}"
  type        = bool
  default     = true
}

variable "enable_services" {
  description = "Enable project APIs. {{UIMeta group=0 order=9 }}"
  type        = bool
  default     = true
}

variable "agent_service_account" {
  description = "If deploying into an existing GCP project outside of the RAD platform, enter a RAD GCP project agent service account, e.g. rad-agent@gcp-project.sr65.iam.gserviceaccount.com, and grant this service account IAM Owner role in the target Google Cloud project. Leave this field blank if deploying into a target project on the RAD platform. {{UIMeta group=0 order=10 updatesafe }}"
  type        = string
  default     = null
}

################################################################################
# SECTION 1: Project Configuration (User-accessible)
################################################################################

variable "resource_creator_identity" {
  description = "The Service Account used by terraform to create resources in the destination project. Assign time limited conditional Basic Owner IAM role in the destination project. {{UIMeta group=1 order=101 }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of trusted users with limited Google Cloud project admin privileges. (e.g. `username@abc.com`). {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = []
}

variable "resource_labels" {
  description = "Labels to assign to resources. {{UIMeta group=0 order=103 }}"
  type        = map(string)
  default     = {}
}

################################################################################
# SECTION 2: Networking Configuration (User-accessible)
################################################################################

variable "existing_project_id" {
  description = "Select an existing project on the RAD platform or enter the project ID of an external GCP project. You must grant Owner role to the RAD GCP Project agent service account when deploying into an external project. {{UIMeta group=2 order=501 }}"
  type        = string
}

variable "network_name" {
  description = "Name assigned to the VPC network. Do not change this value {{UIMeta group=0 order=502 }}"
  type        = string
  default     = "vpc-network"
}

variable "availability_regions" {
  description = "The one or two regions where resources should be configured. The deployment might fail if sufficient resources not available in chosen region. {{UIMeta group=2 order=503 }}"
  type        = list(string)
  default     = ["us-central1"]

  validation {
    condition     = length(var.availability_regions) > 0
    error_message = "At least one availability region must be specified."
  }
}

variable "subnet_cidr_range" {
  description = "List of CIDR ranges for GCE subnets, one per availability region. {{UIMeta group=0 order=504 }}"
  type        = list(string)
  default     = [
    "10.0.0.0/24",
    "10.0.1.0/24"
  ]

  validation {
    condition     = length(var.subnet_cidr_range) > 0
    error_message = "At least one CIDR range must be specified for subnets."
  }

  validation {
    condition = alltrue([
      for cidr in var.subnet_cidr_range :
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))
    ])
    error_message = "All CIDR ranges must be in valid format (e.g., 10.0.0.0/24)."
  }
}

################################################################################
# SECTION 3: Database Configuration (User-accessible)
################################################################################

variable "create_postgres" {
  description = "Select to create PostgreSQL database instance. {{UIMeta group=3 order=400 }}"
  type        = bool
  default     = true
}

variable "postgres_database_availability_type" {
  description = "The availability type of the PostgreSQL instance. ZONAL is cost-effective for development; REGIONAL provides high availability for production. {{UIMeta group=0 order=401 options=ZONAL,REGIONAL }}"
  type        = string
  default     = "ZONAL"
}

variable "postgres_database_version" {
  description = "PostgreSQL database version to use. {{UIMeta group=0 order=402 options=POSTGRES_16,POSTGRES_15,POSTGRES_14 }}"
  type        = string
  default     = "POSTGRES_16"
}

variable "postgres_tier" {
  description = "The machine type to use for PostgreSQL. Supports shared-core and custom machine types such as `db-custom-2-13312`. {{UIMeta group=0 order=403 }}"
  type        = string
  default     = "db-custom-1-3840"
}

variable "postgres_database_flags" {
  description = "List of database flags to assign to the PostgreSQL instance. {{UIMeta group=0 order=404 }}"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "max_connections"
      value = "30000"
    }
  ]
}

variable "create_mysql" {
  description = "Select to create MySQL database instance. {{UIMeta group=3 order=410 }}"
  type        = bool
  default     = false
}

variable "mysql_database_availability_type" {
  description = "The availability type of the MySQL instance. ZONAL is cost-effective for development; REGIONAL provides high availability for production. {{UIMeta group=0 order=411 options=ZONAL,REGIONAL }}"
  type        = string
  default     = "ZONAL"
}

variable "mysql_database_version" {
  description = "MySQL database version to use. {{UIMeta group=0 order=412 options=MYSQL_8_0,MYSQL_5_7 }}"
  type        = string
  default     = "MYSQL_8_0"
}

variable "mysql_tier" {
  description = "The machine type to use for MySQL. Supports shared-core and custom machine types such as `db-custom-2-13312`. {{UIMeta group=0 order=413 }}"
  type        = string
  default     = "db-custom-1-3840"
}

variable "mysql_database_flags" {
  description = "List of database flags to assign to the MySQL instance. {{UIMeta group=0 order=414 }}"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "max_connections"
      value = "30000"
    },
    {
      name  = "local_infile"
      value = "off"
    }
  ]
}


################################################################################
# SECTION 4: Self Managed NFS and Redis
################################################################################

variable "create_network_filesystem" {
  description = "Select to create NFS server for shared file storage and Redis for application caching and session storage using Compute Engine instances. {{UIMeta group=4 order=401 }}"
  type        = bool
  default     = true
}

variable "network_filesystem_machine" {
  description = "NFS server machine type. {{UIMeta group=0 order=402 }}"
  type        = string
  default     = "e2-small"
}

variable "network_filesystem_capacity" {
  description = "Size of NFS server disks in GB. {{UIMeta group=0 order=403 }}"
  type        = number
  default     = 10
}

################################################################################
# SECTION 5: Managed Redis
################################################################################

variable "create_redis" {
  description = "Select to create Managed Redis instance. {{UIMeta group=0 order=520 }}"
  type        = bool
  default     = false
}

variable "redis_tier" {
  description = "The service tier of the Redis instance. {{UIMeta group=0 order=521 options=BASIC,STANDARD_HA }}"
  type        = string
  default     = "BASIC"
}

variable "redis_memory_size_gb" {
  description = "Memory size in GB for the Redis instance. {{UIMeta group=0 order=522 }}"
  type        = number
  default     = 1

  validation {
    condition     = var.redis_memory_size_gb >= 1 && var.redis_memory_size_gb <= 300
    error_message = "Redis memory size must be between 1 and 300 GB."
  }
}

variable "redis_version" {
  description = "Redis version to use. {{UIMeta group=0 order=523 options=REDIS_7_2,REDIS_7_0,REDIS_6_X }}"
  type        = string
  default     = "REDIS_7_2"
}

variable "redis_connect_mode" {
  description = "Network connection mode for Redis. {{UIMeta group=0 order=524 options=DIRECT_PEERING,PRIVATE_SERVICE_ACCESS }}"
  type        = string
  default     = "DIRECT_PEERING"
}

################################################################################
# SECTION 6: Filestore
################################################################################

variable "create_filestore_nfs" {
  description = "Select to create Filestore NFS server. {{UIMeta group=0 order=611 }}"
  type        = bool
  default     = false
}

variable "filestore_tier" {
  description = "The service tier of the filestore instance. {{UIMeta group=0 order=612 options=BASIC_HDD,BASIC_SSD }}"
  type        = string
  default     = "BASIC_HDD"
}

variable "filestore_capacity_gb" {
  description = "Filestore capacity must be at least 1024 GB for BASIC_HDD, and 2560 GB for BASIC_SSD.{{UIMeta group=0 order=613 }}"
  type        = number
  default     = 1024

  validation {
    condition     = var.filestore_capacity_gb >= 1024
    error_message = "Filestore capacity must be at least 1024 GB for BASIC_HDD, and 2560 GB for BASIC_SSD."
  }
}

################################################################################
# SECTION 7: Observability Configuration (User-accessible)
################################################################################

variable "notification_channels" {
  description = "List of notification channels for alerting. {{UIMeta group=0 order=700 }}"
  type        = list(string)
  default     = []
}

variable "alert_cpu_threshold" {
  description = "CPU utilization threshold for alerting (percentage). {{UIMeta group=0 order=701 }}"
  type        = number
  default     = 80
}

variable "alert_memory_threshold" {
  description = "Memory utilization threshold for alerting (percentage). {{UIMeta group=0 order=702 }}"
  type        = number
  default     = 80
}

variable "alert_disk_threshold" {
  description = "Disk utilization threshold for alerting (percentage). {{UIMeta group=0 order=703 }}"
  type        = number
  default     = 80
}
