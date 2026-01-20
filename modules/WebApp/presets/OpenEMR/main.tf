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
  container_port         = 80

  container_resources = {
    cpu_limit    = "2000m"
    memory_limit = "4Gi"
  }

  min_instance_count = 1
  max_instance_count = 1

  # Network
  network_name = var.network_name

  # Service Account
  cloudrun_service_account = var.cloudrun_service_account

  # NFS
  nfs_enabled    = var.nfs_enabled
  nfs_mount_path = var.nfs_mount_path

  # Cloud SQL Volume
  enable_cloudsql_volume = true

  # Probes
  startup_probe_config = {
    enabled               = true
    type                  = "TCP"
    path                  = "/" # Ignored for TCP
    initial_delay_seconds = 240
    timeout_seconds       = 60
    period_seconds        = 240
    failure_threshold     = 5
  }

  health_check_config = {
    enabled               = true
    type                  = "HTTP"
    path                  = "/interface/login/login.php"
    initial_delay_seconds = 300
    timeout_seconds       = 60
    period_seconds        = 60
    failure_threshold     = 3
  }

  environment_variables = merge(var.environment_variables, {
    MYSQL_DATABASE = module.webapp.database_name
    MYSQL_USER     = module.webapp.database_user
    MYSQL_HOST     = module.webapp.database_host
    MYSQL_PORT     = "3306"
    OE_USER        = "admin"
    OE_PASS        = "admin"
    MANUAL_SETUP   = "no"
  })

  secret_environment_variables = merge(var.secret_environment_variables, {
    # Assuming root password secret follows standard naming
    MYSQL_ROOT_PASS = "${module.webapp.database_instance_name}-root-password"
  })
}
