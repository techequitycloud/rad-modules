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
  project   = format("%s-%s", var.project_id_prefix, local.random_id)

  default_apis = [
    # Core Infrastructure & Management
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    
    # Application Deployment
    "run.googleapis.com",
    "cloudfunctions.googleapis.com",
    "clouddeploy.googleapis.com",
    "cloudbuild.googleapis.com",
    
    # Database & Storage
    "sqladmin.googleapis.com",
    "firestore.googleapis.com",
    "datastore.googleapis.com",
    "bigquery.googleapis.com",
    "redis.googleapis.com",
    "memcache.googleapis.com",
    "storage.googleapis.com",  # ✅ FIXED: Replaced storage-api and storage-component
    
    # Firebase Services
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "firebaserules.googleapis.com",
    "identitytoolkit.googleapis.com",
    "fcm.googleapis.com",
    
    # Security & Secrets
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudkms.googleapis.com",
    "binaryauthorization.googleapis.com",
    "iap.googleapis.com",
    "certificatemanager.googleapis.com",
    
    # Monitoring & Operations
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "clouderrorreporting.googleapis.com",
    "cloudprofiler.googleapis.com",
    # ❌ REMOVED: clouddebugger.googleapis.com (deprecated May 2022, shut down May 2023)
    
    # Networking
    "dns.googleapis.com",
    "vpcaccess.googleapis.com",
    
    # Developer & Coding Services
    "containeranalysis.googleapis.com",
    "pubsub.googleapis.com",
    
    # Messaging & Events
    "cloudtasks.googleapis.com",
    "cloudscheduler.googleapis.com",
    "eventarc.googleapis.com",
    
    # Integration & Workflows
    "apigateway.googleapis.com",
    "workflows.googleapis.com",
    "connectgateway.googleapis.com",
  ]

  quota_apis = var.enable_quota_overrides ? [
    "compute.googleapis.com",
    "serviceusage.googleapis.com",
  ] : []

  project_services = var.enable_services ? local.default_apis : []
  all_services     = distinct(concat(local.project_services, local.quota_apis))
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

# Quota overrides for Cloud Run
resource "google_service_usage_consumer_quota_override" "run_quotas" {
  provider = google-beta
  for_each = var.enable_quota_overrides ? var.run_quota_overrides : {}

  project        = google_project.project.project_id
  service        = "run.googleapis.com"
  metric         = urlencode("run.googleapis.com/${each.value.metric}")
  limit          = "/%2Fproject%2F${google_project.project.project_id}"
  override_value = tostring(each.value.limit)
  force          = true

  depends_on = [
    google_project_service.enabled_services
  ]
}

# Quota overrides for Cloud SQL
resource "google_service_usage_consumer_quota_override" "sql_quotas" {
  provider = google-beta
  for_each = var.enable_quota_overrides ? var.sql_quota_overrides : {}

  project        = google_project.project.project_id
  service        = "sqladmin.googleapis.com"
  metric         = urlencode("sqladmin.googleapis.com/${each.value.metric}")
  limit          = "/%2Fproject%2F${google_project.project.project_id}"
  override_value = tostring(each.value.limit)
  force          = true

  depends_on = [
    google_project_service.enabled_services
  ]
}

# Quota overrides for Cloud Storage
resource "google_service_usage_consumer_quota_override" "storage_quotas" {
  provider = google-beta
  for_each = var.enable_quota_overrides ? var.storage_quota_overrides : {}

  project        = google_project.project.project_id
  service        = "storage.googleapis.com"
  metric         = urlencode("storage.googleapis.com/${each.value.metric}")
  limit          = "/%2Fproject%2F${google_project.project.project_id}"
  override_value = tostring(each.value.limit)
  force          = true

  depends_on = [
    google_project_service.enabled_services
  ]
}

# Quota overrides for Secret Manager
resource "google_service_usage_consumer_quota_override" "secretmanager_quotas" {
  provider = google-beta
  for_each = var.enable_quota_overrides ? var.secretmanager_quota_overrides : {}

  project        = google_project.project.project_id
  service        = "secretmanager.googleapis.com"
  metric         = urlencode("secretmanager.googleapis.com/${each.value.metric}")
  limit          = "/%2Fproject%2F${google_project.project.project_id}"
  override_value = tostring(each.value.limit)
  force          = true

  depends_on = [
    google_project_service.enabled_services
  ]
}

# Quota overrides for Cloud Build
resource "google_service_usage_consumer_quota_override" "cloudbuild_quotas" {
  provider = google-beta
  for_each = var.enable_quota_overrides ? var.cloudbuild_quota_overrides : {}

  project        = google_project.project.project_id
  service        = "cloudbuild.googleapis.com"
  metric         = urlencode("cloudbuild.googleapis.com/${each.value.metric}")
  limit          = "/%2Fproject%2F${google_project.project.project_id}"
  override_value = tostring(each.value.limit)
  force          = true

  depends_on = [
    google_project_service.enabled_services
  ]
}

# Quota overrides for Artifact Registry
resource "google_service_usage_consumer_quota_override" "artifactregistry_quotas" {
  provider = google-beta
  for_each = var.enable_quota_overrides ? var.artifactregistry_quota_overrides : {}

  project        = google_project.project.project_id
  service        = "artifactregistry.googleapis.com"
  metric         = urlencode("artifactregistry.googleapis.com/${each.value.metric}")
  limit          = "/%2Fproject%2F${google_project.project.project_id}"
  override_value = tostring(each.value.limit)
  force          = true

  depends_on = [
    google_project_service.enabled_services
  ]
}

# Quota overrides for Pub/Sub
resource "google_service_usage_consumer_quota_override" "pubsub_quotas" {
  provider = google-beta
  for_each = var.enable_quota_overrides ? var.pubsub_quota_overrides : {}

  project        = google_project.project.project_id
  service        = "pubsub.googleapis.com"
  metric         = urlencode("pubsub.googleapis.com/${each.value.metric}")
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
