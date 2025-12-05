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

output "deployment_info" {
  value = {
    deployment_id  = var.deployment_id
    region         = local.region
    project_id = local.project.project_id
  }
}

output "application_info" {
  value = {
    application_dev_url  = var.configure_development_environment ? "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev-${local.project_number}.${local.region}.run.app" : ""
    application_qa_url   = var.configure_nonproduction_environment ? "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa-${local.project_number}.${local.region}.run.app" : ""
    application_prod_url = var.configure_production_environment ? "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod-${local.project_number}.${local.region}.run.app" : ""
  }
}

output "service_info" {
  value = {
    service_dev_url  = var.configure_development_environment ? "https://console.cloud.google.com/run/detail/${local.region}/app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev/metrics?orgonly=true&project=${local.project.project_id}&supportedpurview=organizationId" : ""
    service_qa_url = var.configure_nonproduction_environment ? "https://console.cloud.google.com/run/detail/${local.region}/app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa/metrics?orgonly=true&project=${local.project.project_id}&supportedpurview=organizationId" : ""
    service_prod_url = var.configure_production_environment ? "https://console.cloud.google.com/run/detail/${local.region}/app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod/metrics?orgonly=true&project=${local.project.project_id}&supportedpurview=organizationId" : ""
  }
}

output "cicd_info" {
  value = {
    github_repository = var.configure_continuous_integration ? "https://github.com/${var.application_git_organization}/${local.project.project_id}-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}.git" : ""
    cloud_build_trigger = var.configure_continuous_integration ? "https://console.cloud.google.com/cloud-build/triggers;region=${local.region}?inv=1&invt=AbioWw&orgonly=true&project=${local.project.project_id}&supportedpurview=organizationId" : ""
    cloud_artifact_registry = var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment ? "https://console.cloud.google.com/artifacts?inv=1&invt=AbioeA&orgonly=true&project=${local.project.project_id}&supportedpurview=organizationId" : ""
  }
}
