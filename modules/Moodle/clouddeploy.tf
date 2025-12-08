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
# Create Cloud Deploy resources
#########################################################################

# Resource for creating a Cloud Deploy delivery pipeline
resource "google_clouddeploy_delivery_pipeline" "primary" {
  count      = var.configure_continuous_deployment ? 1 : 0
  location    = local.region          # The location/region where the pipeline will be created
  name        = "${var.application_name}-pipeline-${var.tenant_deployment_id}-${local.random_id}"  # The name of the pipeline
  description = "Application pipeline"  # Description of the pipeline
  project     = local.project.project_id        # The project ID where the pipeline will be created

  # Configuration block for serial pipeline stages
  serial_pipeline {
    stages {
      profiles  = []            # Profiles to use for the stage
      target_id = "dev"         # The target ID for the development stage
    }

    stages {
      profiles  = []            # Profiles to use for the stage
      target_id = "qa"          # The target ID for the QA stage
    }

    stages {
      profiles  = []            # Profiles to use for the stage
      target_id = "prod"        # The target ID for the production stage
    }
  }
}

# Resource for creating a Cloud Deploy target for the development environment
resource "google_clouddeploy_target" "dev" {
  count      = var.configure_continuous_deployment ? 1 : 0
  location          = local.region      # The location/region where the target will be created
  name              = "dev"             # The name of the target
  description       = "dev environment" # Description of the target
  project           = local.project.project_id    # The project ID where the target will be created
  require_approval  = false             # Whether approval is required for deployment to this target

  # Configuration block for Cloud Run target
  run {
    location = "projects/${local.project.project_id}/locations/${local.region}"  # The Cloud Run location
  }
}

# Resource for creating a Cloud Deploy target for the QA environment
resource "google_clouddeploy_target" "qa" {
  count      = var.configure_continuous_deployment ? 1 : 0
  location          = local.region      # The location/region where the target will be created
  name              = "qa"              # The name of the target
  description       = "qa environment"  # Description of the target
  project           = local.project.project_id    # The project ID where the target will be created
  require_approval  = false             # Whether approval is required for deployment to this target

  # Configuration block for Cloud Run target
  run {
    location = "projects/${local.project.project_id}/locations/${local.region}"  # The Cloud Run location
  }
}

# Resource for creating a Cloud Deploy target for the production environment
resource "google_clouddeploy_target" "prod" {
  count      = var.configure_continuous_deployment ? 1 : 0
  location          = local.region      # The location/region where the target will be created
  name              = "prod"            # The name of the target
  description       = "prod environment" # Description of the target
  project           = local.project.project_id    # The project ID where the target will be created
  require_approval  = true              # Whether approval is required for deployment to this target

  # Configuration block for Cloud Run target
  run {
    location = "projects/${local.project.project_id}/locations/${local.region}"  # The Cloud Run location
  }
}

#########################################################################
# Create Cloud Deploy resources for backup
#########################################################################

# Resource for creating a Cloud Deploy delivery pipeline for backups
resource "google_clouddeploy_delivery_pipeline" "backup_pipeline" {
  count      = var.configure_backups && var.configure_continuous_deployment ? 1 : 0
  location    = local.region          # The location/region where the pipeline will be created
  name        = "${var.application_name}-backup-pipeline-${var.tenant_deployment_id}-${local.random_id}"  # The name of the pipeline
  description = "Application backup pipeline"  # Description of the pipeline
  project     = local.project.project_id        # The project ID where the pipeline will be created

  # Configuration block for serial pipeline stages
  serial_pipeline {
    stages {
      profiles  = []            # Profiles to use for the stage
      target_id = "dev-backup"  # The target ID for the development backup stage
    }

    stages {
      profiles  = []            # Profiles to use for the stage
      target_id = "qa-backup"   # The target ID for the QA backup stage
    }

    stages {
      profiles  = []            # Profiles to use for the stage
      target_id = "prod-backup" # The target ID for the production backup stage
    }
  }
}

# Resource for creating a Cloud Deploy target for the development backup environment
resource "google_clouddeploy_target" "dev_backup" {
  count      = var.configure_backups && var.configure_continuous_deployment ? 1 : 0
  location          = local.region      # The location/region where the target will be created
  name              = "dev-backup"      # The name of the target
  description       = "dev backup environment" # Description of the target
  project           = local.project.project_id    # The project ID where the target will be created
  require_approval  = false             # Whether approval is required for deployment to this target

  # Configuration block for Cloud Run target
  run {
    location = "projects/${local.project.project_id}/locations/${local.region}"  # The Cloud Run location
  }
}

# Resource for creating a Cloud Deploy target for the QA backup environment
resource "google_clouddeploy_target" "qa_backup" {
  count      = var.configure_backups && var.configure_continuous_deployment ? 1 : 0
  location          = local.region      # The location/region where the target will be created
  name              = "qa-backup"       # The name of the target
  description       = "qa backup environment"  # Description of the target
  project           = local.project.project_id    # The project ID where the target will be created
  require_approval  = false             # Whether approval is required for deployment to this target

  # Configuration block for Cloud Run target
  run {
    location = "projects/${local.project.project_id}/locations/${local.region}"  # The Cloud Run location
  }
}

# Resource for creating a Cloud Deploy target for the production backup environment
resource "google_clouddeploy_target" "prod_backup" {
  count      = var.configure_backups && var.configure_continuous_deployment ? 1 : 0
  location          = local.region      # The location/region where the target will be created
  name              = "prod-backup"     # The name of the target
  description       = "prod backup environment" # Description of the target
  project           = local.project.project_id    # The project ID where the target will be created
  require_approval  = true              # Whether approval is required for deployment to this target

  # Configuration block for Cloud Run target
  run {
    location = "projects/${local.project.project_id}/locations/${local.region}"  # The Cloud Run location
  }
}

# Null resource to build the Cloud Deploy backup pipeline
resource "null_resource" "build_cloud_deploy_backup_pipeline" {
  count      = var.configure_backups && var.configure_continuous_deployment ? 1 : 0
  triggers = {
    # always_run = "${timestamp()}" # Trigger to always run on apply
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "gcloud deploy releases create release-$(date +%Y%m%d%H%M%S) --project=${local.project.project_id} --region=${local.region} --delivery-pipeline=${google_clouddeploy_delivery_pipeline.backup_pipeline[count.index].name} --skaffold-file=skaffold_backup.yaml"
    working_dir = "${path.module}/scripts/cd"
  }

  depends_on = [
    local_file.backup_manifest,
    local_file.backup_skaffold_manifest,
    google_clouddeploy_delivery_pipeline.backup_pipeline,
    google_clouddeploy_target.dev_backup,
    google_clouddeploy_target.qa_backup,
    google_clouddeploy_target.prod_backup,
    google_cloud_run_v2_job.backup_service # Updated dependency
  ]
}
