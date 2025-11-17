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
  default     = <<-EOT
**Purpose:** This module deploys a digital banking application called "Cyclos" on the Google Kubernetes Engine (GKE). It's a comprehensive solution for financial institutions looking to offer online and mobile banking services.

**What it does:**
- Deploys the Cyclos banking portal on a GKE cluster.
- Sets up a complete environment for the application, including networking, security, and databases.
- Includes features for online payments, mobile banking, and microfinance services.

**Dependencies:** This module requires the `GCP Services` module to be deployed first to prepare the Google Cloud project.
EOT
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP Project","GCP Services"]
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=102 }}"
  type = list(string)
  default = ["GCP", "GKE", "Cloud Build", "Cloud Deploy", "Artifact Registry", "Cloud Storage", "Cloud SQL", "Cloud IAM", "Cloud Networking"]
}


variable "deployment_id" {
  description = "Unique ID suffix for resources.  Leave blank to generate random ID."
  type        = string
  default     = null
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=1 order=102 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of trusted users with limited Google Cloud project admin privileges. (e.g. `username@abc.com`). {{UIMeta group=0 order=103 updatesafe }}"
  type        = list(string)
  default     = []
}

# GROUP 2: Application Project

variable "existing_project_id" {
  description = "Enter the project ID of the destination project. {{UIMeta group=2 order=200 updatesafe }}"
  type        = string
}

# GROUP 3: Network

variable "network_name" {
  description = "Name to be assigned to the network. {{UIMeta group=0 order=301 updatesafe }}"
  type        = string
  default     = "vpc-network"
}

# GROUP 5: Storage

variable "create_cloud_storage" {
  description = "Select to enable access to Cloud Storage. {{UIMeta group=0 order=501 updatesafe }}"
  type        = bool
  default     = true  # Change to true to create the resource
}

# GROUP 5: Deploy

variable "application_name" {
  description = "Specify application name. The application name is used to identify configured resources alongside other attributes that ensures uniqueness. {{UIMeta group=0 order=501 updatesafe}}"
  type        = string
  default     = "appname"
}

variable "application_database_user" {
  description = "Specify application database user name. The actual database user name includes the customer identifier, environment and deployment id to ensure uniqueness. {{UIMeta group=0 order=502 updatesafe}}"
  type        = string
  default     = "dbuser"
}

variable "application_database_name" {
  description = "Specify application database name. The actual database name includes the customer identifier, environment and deployment id to ensure uniqueness. {{UIMeta group=0 order=503 updatesafe }}"
  type        = string
  default     = "dbname"
}

variable "application_database_type" {
  description = "Specify application database type. Options are MYSQL or POSTGRES. {{UIMeta group=0 order=503 updatesafe }}"
  type        = string
  default     = "POSTGRES"
}

variable "application_version" {
  description = "Enter application version. Container images are tagged with this version number. {{UIMeta group=0 order=504 updatesafe}}"
  type        = string
  default     = "1.0"
}

variable "application_secure_path" {
  description = "Enter the application secure path. Cloud Armour is configured to restrict traffic to this path. {{UIMeta group=0 order=512 updatesafe}}"
  type        = string
  default     = ""
}

variable "application_authorized_network" {
  description = "Enter the application authorized network. Cloud Armour is configured to allow traffic from this network. {{UIMeta group=0 order=513 updatesafe}}"
  type        = set(string)
  default     = []
}

# GROUP 6: CICD

variable "application_git_installation_id" {
  description = "Specify the application installation ID. {{UIMeta group=0 order=602 updatesafe}}"
  type        = string
  default     = "38735316"
}

variable "application_git_organization" {
  description = "Specify the github organization. {{UIMeta group=0 order=603 updatesafe}}"
  type        = string
  default     = "techequitycloud"
}

# GROUP 7: Tenant

variable "tenant_deployment_id" {
  description = "Specify a client or application deployment id. This uniquely identifies the client or application deployment. {{UIMeta group=6 order=701 updatesafe}}"
  type        = string
}

variable "configure_development_environment" {
  description = "Select to configure development environment. Code is committed to the dev branch in the github repository. {{UIMeta group=6 order=703 updatesafe }}"
  type        = bool
  default     = false
}

variable "configure_nonproduction_environment" {
  description = "Select to configure staging environment. Code is committed to the qa branch in the github repository. {{UIMeta group=6 order=704 updatesafe }}"
  type        = bool
  default     = false
}

variable "configure_production_environment" {
  description = "Select to configure production environment. Code is committed to the prod branch in the github repository. {{UIMeta group=6 order=705 updatesafe }}"
  type        = bool
  default     = false
}

# GROUP 8: Tenant

variable "configure_continuous_integration" {
  description = "Select the checkbox to configure GitHub continuous integration and continous delivery pipeline that supports single and multi-region deployment. {{UIMeta group=7 order=803 updatesafe}}"
  type        = bool
  default     = false
}

variable "configure_continuous_deployment" {
  description = "Select the checkbox to configure continous deployment pipeline. Implements a continuous delivery pipeline on the primary deployment region using Cloud Deploy. {{UIMeta group=7 order=801 updatesafe}}"
  type        = bool
  default     = false
}

variable "application_git_token" {
  description = "Specify a github classic token with following privileges needed to configure the code repository: delete_repo, read:org, repo. {{UIMeta group=7 order=804 updatesafe}}"
  type        = string
  default     = ""
  sensitive   = true
}

variable "application_git_usernames" {
  description = "Specify the usernames to add as collaborators to the git repository. {{UIMeta group=7 order=805 updatesafe}}"
  type        = set(string)
  default     = []
}

variable "configure_monitoring" {
  description = "Select this option to configure monitoring. Configures uptime checks, SLOs and SLIs for application, and CPU utilization monitoring for NFS virtual machine. {{UIMeta group=8 order=805 updatesafe}}"
  type        = bool
  default     = true
}

variable "configure_backups" {
  description = "Select to schedule application database backups. Configures a Cloud Scheduler trigger to execute a Cloud Run backup job. {{UIMeta group=4 order=806 updatesafe }}"
  type        = bool
  default     = true
}

variable "application_backup_schedule" {
  description = "Enter the application backup schedule in cron format. This is used to configure the Cloud Scheduler cron job. {{UIMeta group=4 order=807 updatesafe }}"
  type        = string
  default     = "0 0 * * *"
}

variable "application_backup_fileid" {
  description = "Enter application backup file ID. When enabled, terraform attempts to download the file from Google Drive, and if found, imports the backup files during deployment. {{UIMeta group=4 order=808 updatesafe}}"
  type        = string
  default     = "1NWsxy_PHGKn9LJnXaQh5FFqp_WKjYEsJ"
}

variable "configure_application_security" {
  description = "Select this checkbox to configure web application security.  Configures a global load balancer with Cloud Armor web application security. {{UIMeta group=0 order=511 updatesafe }}"
  type        = bool
  default     = false
}
