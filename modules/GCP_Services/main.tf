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

#########################################################################
# Configure Project Resources 
#########################################################################

# Define local values for use throughout the Terraform configuration
locals {
  random_id = var.deployment_id != null ? var.deployment_id : random_id.default[0].hex

  project = ((length(data.google_project.existing_project) > 0 
        ? data.google_project.existing_project  
        : null) 
  ) 

  region  = tolist(var.availability_regions)[0]
  regions = tolist(var.availability_regions)
  project_number = try(data.google_project.existing_project.number, "")

  default_apis = [
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iamcredentials.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "storage-api.googleapis.com",
    "pubsub.googleapis.com",
    "compute.googleapis.com",
    "iap.googleapis.com",
    "networkmanagement.googleapis.com",
    "servicenetworking.googleapis.com",
    "dns.googleapis.com",
    "container.googleapis.com",
    "sql-component.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "file.googleapis.com",
    "binaryauthorization.googleapis.com",
    "containeranalysis.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudkms.googleapis.com",
    "clouddeploy.googleapis.com",
    "websecurityscanner.googleapis.com",
    "containersecurity.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "redis.googleapis.com",
    "memorystore.googleapis.com",
    "anthos.googleapis.com",
    "mesh.googleapis.com",
    "meshtelemetry.googleapis.com",
    "gkeconnect.googleapis.com",
    "gkehub.googleapis.com",
    "anthospolicycontroller.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
    "firestore.googleapis.com",
   ]

  project_services = var.enable_services ? local.default_apis : []
}

# Data source to fetch the list of available compute zones in the region
data "google_compute_zones" "available_zones" {
  project = local.project.project_id
  region  = local.region
  status  = "UP" 

  depends_on = [
    null_resource.api_poll
  ]
}

# Generate a random ID if a deployment ID is not provided
resource "random_id" "default" {
  count       = var.deployment_id == null ? 1 : 0 
  byte_length = 2 
}

data "google_project" "existing_project" {
  project_id = trimspace(var.existing_project_id)
}

#########################################################################
# Enable APIs
#########################################################################

# Resource to enable APIs on the selected Google Cloud project
resource "google_project_service" "enabled_services" {
  for_each                   = toset(local.project_services) 
  project                    = local.project.project_id 
  service                    = each.value                   
  
  disable_dependent_services = false 
  disable_on_destroy         = false 
}

# Resource to introduce a delay in the Terraform apply operation.
resource "null_resource" "api_poll" {
  depends_on = [
    google_project_service.enabled_services
  ]
  provisioner "local-exec" {
    command = <<EOT
      #!/bin/bash
      MAX_RETRIES=24
      RETRY_INTERVAL=10
      ENABLED_APIS=()
      APIS_TO_ENABLE=("${join("\" \"", local.project_services)}")

      for ((i=1; i<=MAX_RETRIES; i++)); do
        ENABLED_APIS=($$(gcloud services list --enabled --project "${local.project.project_id}" --format="value(config.name)"))

        ALL_ENABLED=true
        for api in "$${APIS_TO_ENABLE[@]}"; do
          FOUND=false
          for enabled_api in "$${ENABLED_APIS[@]}"; do
            if [[ "$api" == "$enabled_api" ]]; then
              FOUND=true
              break
            fi
          done
          if [[ "$FOUND" == "false" ]]; then
            ALL_ENABLED=false
            break
          fi
        done

        if [[ "$ALL_ENABLED" == "true" ]]; then
          echo "All APIs are enabled."
          exit 0
        fi

        echo "Waiting for APIs to be enabled... (Attempt $i/$MAX_RETRIES)"
        sleep $RETRY_INTERVAL
      done

      echo "Timeout: APIs not enabled after $(($MAX_RETRIES * $RETRY_INTERVAL)) seconds."
      exit 1
EOT
  }
}

#########################################################################
# Root Password for Database
#########################################################################

# Resource for creating a random password for database additional user
resource "random_password" "root_password" {
  length           = 16          
  special          = true        
  override_special = "_%@"       
}
