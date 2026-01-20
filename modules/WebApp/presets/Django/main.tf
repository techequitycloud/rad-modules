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

module "webapp" {
  source = "../../"

  # Project & Deployment
  existing_project_id  = var.existing_project_id
  deployment_id        = var.deployment_id
  tenant_deployment_id = var.tenant_deployment_id
  deployment_region    = var.deployment_region

  # Application
  application_name          = var.application_name
  application_version       = var.application_version
  application_database_name = var.application_database_name
  application_database_user = var.application_database_user
  database_type             = var.database_type

  # Container
  container_image_source = var.container_image_source
  container_image        = var.container_image
  container_build_config = var.container_build_config
  container_port         = 8080

  # Network
  network_name = var.network_name

  # Service Account
  cloudrun_service_account = var.cloudrun_service_account

  # Cloud SQL Volume
  enable_cloudsql_volume     = true
  cloudsql_volume_mount_path = "/cloudsql"

  environment_variables        = var.environment_variables
  secret_environment_variables = var.secret_environment_variables
}

# Post-deployment update for CSRF origin
resource "null_resource" "update_csrf_origin" {
  triggers = {
    service_id = module.webapp.service_name
  }

  provisioner "local-exec" {
    command = <<EOF
      IMPERSONATE_FLAG=""
      if [ -n "${var.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${var.impersonation_service_account}"
        echo "Using impersonation: ${var.impersonation_service_account}"
      fi

      SERVICE_NAME="${module.webapp.service_name}"
      REGION="${var.deployment_region}"
      PROJECT="${var.existing_project_id}"

      if [ -n "$SERVICE_NAME" ]; then
        URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT --format 'value(uri)')
        gcloud run services update $SERVICE_NAME \
          --region $REGION \
          --project $PROJECT \
          --set-env-vars CLOUDRUN_SERVICE_URLS=$URL \
          $IMPERSONATE_FLAG
      fi
    EOF
  }
  depends_on = [module.webapp]
}
