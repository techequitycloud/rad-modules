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
  project        = try(data.google_project.existing_project, null)
  project_number = try(local.project.number, null)

  default_apis = [
    "vmwareengine.googleapis.com",
    "vmmigration.googleapis.com",
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
  ]

  project_services = var.enable_services ? local.default_apis : []

  ven_name             = "altostrat-${local.random_id}-ven"
  private_cloud_name   = "altostrat-${local.random_id}-private-cloud"
  network_policy_name  = "altostrat-${local.random_id}-edge-policy"
  network_peering_name = "altostrat-${local.random_id}-vpc-ven"
  peer_vpc_name        = "altostrat-${local.random_id}-vpc"
  jump_host_name       = "altostrat-${local.random_id}-jump-host"
}

resource "random_id" "default" {
  count       = (var.deployment_id == null || var.deployment_id == "") ? 1 : 0
  byte_length = 2
}

data "google_project" "existing_project" {
  project_id = trimspace(var.project_id)
}

resource "google_project_service" "enabled_services" {
  for_each                   = toset(local.project_services)
  project                    = local.project.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}

# Grant roles/iam.serviceAccountUser to the VM Migration service agent so it
# can act as any SA in the project (required for Migrate to Virtual Machines).
resource "google_project_iam_member" "vmmigration_sa_user" {
  project = local.project.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:service-${local.project.number}@gcp-sa-vmmigration.iam.gserviceaccount.com"

  depends_on = [google_project_service.enabled_services]

  lifecycle {
    prevent_destroy = true
  }
}
