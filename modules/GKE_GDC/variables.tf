/**
 * Copyright 2023 Google LLC
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

// GROUP 1: Provider 

variable "module_description" {
  description = "The description of the module. {{UIMeta group=0 order=100 }}"
  type        = string
  default     = <<-EOT
**Purpose:** This module deploys an advanced, enterprise-grade banking portal on Google Kubernetes Engine (GKE) Enterprise Edition. It is designed for financial institutions that need a highly scalable, secure, and feature-rich platform for their banking applications.

**What it does:**
- Deploys a microservices-based banking application on GKE Enterprise.
- Utilizes advanced GKE Enterprise features like Cloud Service Mesh, Config Management, and Policy Controller for enhanced security and management.
- Provides a centralized dashboard for managing banking services across different environments (eg, cloud and on-premises).

**Dependencies:** This module deploys into an existing Google Cloud project.
EOT
}

variable "module_dependency" {
  description = "Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }}"
  type        = list(string)
  default     = ["GCP Project"]
}

variable "module_services" {
  description = "Specify the module services. {{UIMeta group=0 order=102 }}"
  type = list(string)
  default = ["GCP", "GKE", "GKE Hub", "Compute Engine", "Cloud Load Balancing", "Cloud Firewall", "Filestore", "Cloud IAM", "Cloud Logging", "Cloud Monitoring"]
}

variable "credit" {
  description = "Specify the module cost {{UIMeta group=0 order=103 }}"
  type        = number
  default     = 250
}

variable "require_credit_purchases" {
  description = "Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=104 }}"
  type        = bool
  default     = false
}

variable "resource_creator_identity" {
  description = "The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=1 order=102 updatesafe }}"
  type        = string
  default     = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}

variable "trusted_users" {
  description = "List of trusted users (e.g. `username@abc.com`). {{UIMeta group=0 order=103 updatesafe }}"
  type        = list(string)
  default     = []
}

variable "deployment_id" {
  description = "Unique ID suffix for resources.  Leave blank to generate random ID."
  type        = string
  default     = null
}

// GROUP 2: Main

variable "existing_project_id" {
  description = "Enter the project ID of the destination project. {{UIMeta group=2 order=200 updatesafe }}"
  type        = string
}

variable "credentials_file" {
  description = <<EOT
    Path to the Google Cloud Service Account key file.
    This is the key that will be used to authenticate the provider with the Cloud APIs
  EOT
  type        = string
}

variable "resources_path" {
  description = "Path to the resources folder with the template files"
  type        = string
}

variable "region" {
  description = "Google Cloud Region in which the Compute Engine VMs should be provisioned. List - https://cloud.google.com/compute/docs/regions-zones#available. {{UIMeta group=2 order=510 }}"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone within the selected Google Cloud Region that is to be used. List - https://cloud.google.com/compute/docs/regions-zones#available. {{UIMeta group=2 order=511 }}"
  type        = string
  default     = "us-central1-b"
}

variable "username" {
  description = "The name of the user to be created on each Compute Engine VM to execute the init script"
  type        = string
  default     = "tfadmin"
}

variable "min_cpu_platform" {
  description = "Minimum CPU architecture upon which the Compute Engine VMs are to be scheduled"
  type        = string
  default     = "Intel Haswell"
}

variable "enable_nested_virtualization" {
  description = "Enable nested virtualization on the Compute Engine VMs are to be scheduled"
  type        = string
  default     = "true"
}

variable "machine_type" {
  description = "Google Cloud machine type to use when provisioning the Compute Engine VMs"
  type        = string
  default     = "n1-standard-8"
}

variable "image" {
  description = <<EOF
    The source image to use when provisioning the Compute Engine VMs.
    Use 'gcloud compute images list' to find a list of all available images
  EOF
  type        = string
  default     = "ubuntu-2204-jammy-v20251002"
}

variable "image_project" {
  description = "Project name of the source image to use when provisioning the Compute Engine VMs"
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "image_family" {
  description = <<EOT
    Source image to use when provisioning the Compute Engine VMs.
    The source image should be one that is in the selected image_project
  EOT
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "boot_disk_type" {
  description = "Type of the boot disk to be attached to the Compute Engine VMs"
  type        = string
  default     = "pd-ssd"
}

variable "boot_disk_size" {
  description = "Size of the primary boot disk to be attached to the Compute Engine VMs in GBs"
  type        = number
  default     = 50
}

variable "gpu" {
  description = <<EOF
    GPU information to be attached to the provisioned GCE instances.
    See https://cloud.google.com/compute/docs/gpus for supported types
  EOF
  type        = object({ type = string, count = number })
  default     = { count = 0, type = "" }
}

variable "network" {
  description = "VPC network to which the provisioned Compute Engine VMs is to be connected to"
  type        = string
  default     = "default"
}

variable "tags" {
  description = "List of tags to be associated to the provisioned Compute Engine VMs"
  type        = list(string)
  default     = ["http-server", "https-server"]
}

variable "anthos_service_account_name" {
  description = "Name given to the Service account that will be used by the Anthos cluster components"
  type        = string
}

variable "primary_apis" {
  description = "List of primary Google Cloud APIs to be enabled for this deployment"
  type        = list(string)
  default = [
    "cloudresourcemanager.googleapis.com",
  ]
}

variable "secondary_apis" {
  description = "List of secondary Google Cloud APIs to be enabled for this deployment"
  type        = list(string)
  default = [
    "anthos.googleapis.com",
    "anthosgke.googleapis.com",
    "container.googleapis.com",
    "gkeconnect.googleapis.com",
    "gkehub.googleapis.com",
    "serviceusage.googleapis.com",
    "stackdriver.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    "anthosaudit.googleapis.com",
    "opsconfigmonitoring.googleapis.com",
    "file.googleapis.com",
    "connectgateway.googleapis.com"
  ]
}

variable "abm_cluster_id" {
  description = "Unique id to represent the Anthos Cluster to be created"
  type        = string
  default     = "gke-bm-cluster"
}

variable "gcp_login_accounts" {
  description = "GCP account email addresses that must be allowed to login to the cluster using Google Cloud Identity."
  type        = list(string)
  default     = []
}

variable "mode" {
  description = <<EOF
    Indication of the execution mode. By default the terraform execution will end
    after setting up the GCE VMs where the Anthos bare metal clusters can be deployed.

    **setup:** create and initialize the GCE VMs required to install Anthos bare metal.

    **install:** everything up to 'setup' mode plus automatically run Anthos bare metal installation steps as well.

    **manuallb:** similar to 'install' mode but Anthos on bare metal is installed with ManualLB mode.
  EOF
  type        = string
  default     = "setup"

  validation {
    condition     = contains(["setup", "install", "manuallb"], var.mode)
    error_message = "Allowed execution modes are: setup, install, manuallb."
  }
}

variable "abm_version" {
  description = "Version of Anthos Bare Metal"
  type        = string
  default     = "1.14.1"
}

variable "as_sub_module" {
  description = "This script is being run as a sub module; thus output extra variables"
  type        = bool
  default     = false
}

variable "nfs_server" {
  description = "Provision a Google Filestore instance for NFS shared storage"
  type        = bool
  default     = false
}

# [START anthosbaremetal_node_prefix]
# [START anthos_bm_node_prefix]
###################################################################################
# The recommended instance count for High Availability (HA) is 3 for Control plane
# and 2 for Worker nodes.
###################################################################################
variable "instance_count" {
  description = "Number of instances to provision per layer (Control plane and Worker nodes) of the cluster"
  type        = map(any)
  default = {
    "controlplane" : 3
    "worker" : 2
  }
}
# [END anthos_bm_node_prefix]
# [END anthosbaremetal_node_prefix]
