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

locals {
  devops_roles = [
    "roles/compute.admin",
    "roles/run.admin",
    "roles/cloudsql.admin",
    "roles/storage.admin",
    "roles/secretmanager.admin",
    "roles/iam.serviceAccountUser",
    "roles/artifactregistry.admin",
    "roles/cloudbuild.builds.editor",
    "roles/cloudscheduler.admin",
    "roles/logging.admin",
    "roles/monitoring.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/clouddeploy.admin",
    "roles/viewer",
  ]

  # Flatten user and role combinations
  user_roles = flatten([
    for user in var.trusted_users : [
      for role in local.devops_roles : {
        user = user
        role = role
      }
    ]
  ])
}

resource "google_project_iam_member" "devops_permissions" {
  for_each = {
    for entry in local.user_roles : "${entry.user}-${entry.role}" => entry
  }

  project = google_project.project.project_id
  role    = each.value.role
  member  = "user:${each.value.user}"
}
