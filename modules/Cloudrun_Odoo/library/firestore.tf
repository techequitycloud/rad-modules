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
  firestore_instance = format("firestore-db-%s", local.random_id)
}

resource "google_firestore_database" "database" {
  count                             = var.create_firestore ? 1 : 0
  project                           = local.project.project_id
  name                              = local.firestore_instance
  location_id                       = local.region
  type                              = "FIRESTORE_NATIVE"
  concurrency_mode                  = "OPTIMISTIC"
  app_engine_integration_mode       = "DISABLED"
  point_in_time_recovery_enablement = "POINT_IN_TIME_RECOVERY_ENABLED"
  delete_protection_state           = "DELETE_PROTECTION_DISABLED"

  depends_on = [
    module.foundation_platform,
    google_project_service.enabled_services,
  ]
}

resource "google_firestore_backup_schedule" "daily-backup" {
  count    = var.create_firestore ? 1 : 0
  project  = local.project.project_id
  database = local.firestore_instance
  retention = "604800s"
  daily_recurrence {}

  depends_on = [
    google_firestore_database.database,
  ]
}
