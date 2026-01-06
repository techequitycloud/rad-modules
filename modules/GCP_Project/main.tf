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
  random_id = var.deployment_id != null ? var.deployment_id : random_id.default[0].hex
  project = format("%s-%s", var.project_id_prefix, local.random_id)

  default_apis = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "clouddeploy.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "firebaserules.googleapis.com",
    "firestore.googleapis.com",
    "identitytoolkit.googleapis.com",
    "fcm.googleapis.com",
    "cloudfunctions.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "dns.googleapis.com",
    "cloudtrace.googleapis.com",
    "clouderrorreporting.googleapis.com",
    "cloudtasks.googleapis.com",
    "cloudscheduler.googleapis.com",
  ]

  quota_apis = var.enable_quota_overrides ? [
    "compute.googleapis.com",
    "serviceusage.googleapis.com",
  ] : []

  project_services = var.enable_services ? local.default_apis : []
  all_services = distinct(concat(local.project_services, local.quota_apis))
}

resource "random_id" "default" {
  count       = var.deployment_id == null ? 1 : 0
  byte_length = 2
}

resource "google_project" "project" {
  name            = local.project
  project_id      = local.project
  folder_id       = var.module_folder_id != "" ? var.module_folder_id : null
  billing_account = var.billing_account_id
  org_id          = var.module_folder_id != "" ? null : var.organization_id
  deletion_policy = "DELETE"
}

resource "google_project_service" "enabled_services" {
  for_each                   = toset(local.all_services)
  project                    = google_project.project.project_id
  service                    = each.value
  disable_dependent_services = true
  disable_on_destroy         = true
}

# Quota overrides for Compute Engine resources
resource "google_service_usage_consumer_quota_override" "compute_quotas" {
  provider = google-beta
  for_each = var.enable_quota_overrides ? var.quota_overrides : {}

  project        = google_project.project.project_id
  service        = "compute.googleapis.com"
  metric         = urlencode("compute.googleapis.com/${each.value.metric}")
  limit          = "/%2Fproject%2F${google_project.project.project_id}"
  override_value = tostring(each.value.limit)
  force          = true

  depends_on = [
    google_project_service.enabled_services
  ]
}

resource "google_billing_budget" "budget" {
  billing_account = var.billing_account_id
  display_name    = "Project Budget - ${local.project}"

  budget_filter {
    projects = ["projects/${google_project.project.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = var.billing_budget_amount
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }

  threshold_rules {
    threshold_percent = 0.8
  }

  threshold_rules {
    threshold_percent = 1.0
  }

  dynamic "all_updates_rule" {
    for_each = length(var.billing_budget_alert_emails) > 0 ? [1] : []
    content {
      pubsub_topic                     = null
      schema_version                   = "1.0"
      monitoring_notification_channels = []
      disable_default_iam_recipients   = false
    }
  }
}
