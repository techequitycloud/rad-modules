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
    "containeranalysis.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudkms.googleapis.com",
    "websecurityscanner.googleapis.com",
    "containersecurity.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "redis.googleapis.com",
    "memorystore.googleapis.com",
    "firestore.googleapis.com",
   ]

  project_services = var.enable_services ? local.default_apis : []
}

# Generate a random ID if a deployment ID is not provided
resource "random_id" "default" {
  count       = var.deployment_id == null ? 1 : 0 
  byte_length = 2 
}

# Data source to fetch existing project
data "google_project" "existing_project" {
  project_id = trimspace(var.existing_project_id)
}

#########################################################################
# Enable APIs
#########################################################################

# Enable required services on the project
resource "google_project_service" "gcp_services" {
  for_each = toset(local.project_services)
  
  project = local.project.project_id
  service = each.value
  
  disable_dependent_services = false
  disable_on_destroy         = false
  
  # Allow sufficient time for API enablement
  timeouts {
    create = "30m"
    update = "40m"
  }
}

# Initial wait for API enablement to propagate
resource "time_sleep" "wait_for_apis" {
  depends_on      = [google_project_service.gcp_services]
  create_duration = "60s"
}

# Verify critical APIs are fully enabled
resource "null_resource" "api_poll" {
  triggers = {
    services = join(",", [for s in google_project_service.gcp_services : s.service])
  }

  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "=========================================="
      echo "Verifying API enablement"
      echo "Project: ${local.project.project_id}"
      echo "=========================================="
      
      CRITICAL_APIS=(
        "container.googleapis.com"
        "compute.googleapis.com"
        "iam.googleapis.com"
      )
      
      MAX_WAIT=180
      ELAPSED=0
      SLEEP_INTERVAL=15
      
      echo ""
      echo "⏳ Waiting for APIs to be fully enabled (max $${MAX_WAIT}s)..."
      echo ""
      
      while [ $ELAPSED -lt $MAX_WAIT ]; do
        ALL_ENABLED=true
        
        for api in "$${CRITICAL_APIS[@]}"; do
          if gcloud services list --enabled \
            --project="${local.project.project_id}" \
            --filter="config.name:$api" \
            --format="value(config.name)" 2>/dev/null | grep -q "$api"; then
            echo "  ✓ $api is enabled"
          else
            echo "  ⏳ $api is not yet enabled"
            ALL_ENABLED=false
          fi
        done
        
        if [ "$ALL_ENABLED" = true ]; then
          echo ""
          echo "✅ All critical APIs are enabled and ready!"
          exit 0
        fi
        
        echo ""
        echo "⏳ Retrying in $${SLEEP_INTERVAL}s... (elapsed: $${ELAPSED}s)"
        sleep $SLEEP_INTERVAL
        ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
      done
      
      echo ""
      echo "❌ Timeout: APIs not enabled after $${MAX_WAIT}s"
      echo "This may indicate a permission issue or API quota problem"
      exit 1
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    google_project_service.gcp_services,
    time_sleep.wait_for_apis
  ]
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

#########################################################################
# Root Password for Database
#########################################################################

# Resource for creating a random password for database additional user
resource "random_password" "root_password" {
  length           = 16          
  special          = true        
  override_special = "_%@"       
}
