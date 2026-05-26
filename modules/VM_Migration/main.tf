/**
 * Copyright 2024 Google LLC
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

locals {
  random_id      = (var.deployment_id != null && var.deployment_id != "") ? var.deployment_id : random_id.default[0].hex
  project      = try(data.google_project.existing_project, null)

  default_apis = [
    "migrationcenter.googleapis.com",
    "compute.googleapis.com",
    "storage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
  ]

  peer_vpc_name    = "migcenter-${local.random_id}-vpc"
  windows_vm_name  = "migcenter-${local.random_id}-winvm01"
  linux_vm_prefix  = "migcenter-${local.random_id}-linvm"
  ssh_key_bucket   = "migcenter-${local.random_id}-mc-keys"
  mc_source_name   = "migcenter-${local.random_id}-mc-source"
  aws_import_name  = "migcenter-${local.random_id}-aws-import"
}

resource "random_id" "default" {
  count       = (var.deployment_id == null || var.deployment_id == "") ? 1 : 0
  byte_length = 2
}

data "google_project" "existing_project" {
  project_id = trimspace(var.project_id)
}

resource "google_project_service" "enabled_services" {
  for_each                   = toset(local.default_apis)
  project                    = local.project.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}
