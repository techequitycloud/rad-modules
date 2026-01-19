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

#########################################################################
# Pub/Sub Topic
#########################################################################

resource "google_pubsub_topic" "events" {
  count   = var.create_pubsub_topic ? 1 : 0

  project = local.project.project_id
  name    = "app-events-${local.random_id}"

  labels = {
    environment = "production"
    managed-by  = "terraform"
  }

  message_retention_duration = var.pubsub_message_retention_duration

  depends_on = [
    resource.time_sleep.wait_for_apis,
  ]
}

#########################################################################
# Pub/Sub Subscription
#########################################################################

resource "google_pubsub_subscription" "events_subscription" {
  count   = var.create_pubsub_topic ? 1 : 0

  project = local.project.project_id
  name    = "app-events-sub-${local.random_id}"
  topic   = google_pubsub_topic.events[0].name

  # Acknowledgement deadline
  ack_deadline_seconds = 20

  # Message retention
  message_retention_duration = var.pubsub_message_retention_duration
  retain_acked_messages      = false

  # Expiration policy
  expiration_policy {
    ttl = "2678400s"  # 31 days
  }

  # Retry policy
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  labels = {
    environment = "production"
    managed-by  = "terraform"
  }

  depends_on = [
    google_pubsub_topic.events,
  ]
}

#########################################################################
# IAM Permissions for Pub/Sub
#########################################################################

# Grant Cloud Run service account publisher access
resource "google_pubsub_topic_iam_member" "cloudrun_publisher" {
  count   = var.create_pubsub_topic ? 1 : 0

  project = local.project.project_id
  topic   = google_pubsub_topic.events[0].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${local.cloudrun_sa_email}"

  depends_on = [
    google_pubsub_topic.events,
    google_service_account.cloud_run_sa_admin,
  ]
}

# Grant Cloud Run service account subscriber access
resource "google_pubsub_subscription_iam_member" "cloudrun_subscriber" {
  count        = var.create_pubsub_topic ? 1 : 0

  project      = local.project.project_id
  subscription = google_pubsub_subscription.events_subscription[0].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${local.cloudrun_sa_email}"

  depends_on = [
    google_pubsub_subscription.events_subscription,
    google_service_account.cloud_run_sa_admin,
  ]
}

# Grant Cloud Build service account publisher access
resource "google_pubsub_topic_iam_member" "cloudbuild_publisher" {
  count   = var.create_pubsub_topic ? 1 : 0

  project = local.project.project_id
  topic   = google_pubsub_topic.events[0].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${local.cloudbuild_sa_email}"

  depends_on = [
    google_pubsub_topic.events,
    google_service_account.cloud_build_sa_admin,
  ]
}
