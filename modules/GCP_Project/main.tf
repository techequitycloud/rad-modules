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
    "billingbudgets.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com" # Often needed with monitoring
  ]

  project_services = var.enable_services ? local.default_apis : []
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
  for_each                   = toset(local.project_services)
  project                    = google_project.project.project_id
  service                    = each.value
  disable_dependent_services = true
  disable_on_destroy         = true
}

resource "google_monitoring_notification_channel" "email" {
  for_each = var.billing_budget_amount != null ? toset(var.billing_budget_notification_email_addresses) : []

  project      = google_project.project.project_id
  display_name = "Email Notification Channel - ${each.value}"
  type         = "email"

  labels = {
    email_address = each.value
  }

  depends_on = [google_project_service.enabled_services]
}

resource "google_billing_budget" "budget" {
  count = var.billing_budget_amount != null ? 1 : 0

  billing_account = var.billing_account_id
  display_name    = "Budget for ${google_project.project.name}"

  budget_filter {
    projects               = ["projects/${google_project.project.number}"]
    credit_types_treatment = var.billing_budget_credit_types_treatment
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = var.billing_budget_amount
    }
  }

  dynamic "threshold_rules" {
    for_each = var.billing_budget_alert_spent_percents
    content {
      threshold_percent = threshold_rules.value
    }
  }

  all_updates_rule {
    monitoring_notification_channels = [for c in google_monitoring_notification_channel.email : c.name]
    disable_default_iam_recipients   = length(var.billing_budget_notification_email_addresses) > 0 ? true : false
  }

  depends_on = [google_project_service.enabled_services]
}

resource "google_project_iam_member" "role_trusted" {
  for_each = toset(var.trusted_users)
  member   = "user:${each.value}"
  project  = google_project.project.project_id
  role     = "roles/viewer"
}
