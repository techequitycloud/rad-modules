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

# Configure alert policy for compute engine instances
resource "google_monitoring_alert_policy" "alert_policy" {
  count   = var.configure_monitoring ? 1 : 0  # Updated count condition
  project = local.project.project_id
  display_name = "app${var.application_name}-cpu-utilization-alert-policy-${var.tenant_deployment_id}-${local.random_id}"
  documentation {
    content = "The $${metric.display_name} of the $${resource.type} $${resource.label.instance_id} in $${resource.project} has exceeded 90% for over 1 minute."
  }
  combiner     = "OR"
  conditions {
    display_name = "Condition 1"
    condition_threshold {
        comparison = "COMPARISON_GT"
        duration = "60s"
        filter = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
        threshold_value = "0.9"
        trigger {
          count = "1"
        }
    }
  }

  alert_strategy {
    notification_channel_strategy {
        renotify_interval = "1800s"
        notification_channel_names = [google_monitoring_notification_channel.email[count.index].name]
    }
  }

  notification_channels = [google_monitoring_notification_channel.email[count.index].name]

  user_labels = {
    severity = "warning"
  }
}

# Configuration for a notification channel in Google Cloud Monitoring.
resource "google_monitoring_notification_channel" "email" {
  count   = var.configure_monitoring ? 1 : 0  # Updated count condition
  # Specifies the project in which the notification channel is created.
  project = local.project.project_id
  # Human-readable name for the notification channel.
  display_name = "app${var.application_name}-notification-channel-${var.tenant_deployment_id}-${local.random_id}"
  # Type of the notification channel (email in this case).
  type         = "email"
  labels = {
    # Email address where notifications will be sent.
    email_address = tolist(var.trusted_users)[0] # The first email
  }
  # Whether to force delete the notification channel when it's removed from Terraform configuration.
  force_delete = true
}

#########################################################################
# Configure resources
#########################################################################
# Define a service for Cloud Run to be monitored.
resource "google_monitoring_service" "cloud_run" {
  count =  (var.configure_monitoring && var.configure_environment) ? length(local.regions) : 0
  service_id   = "app${var.application_name}-monitoring-service-${var.tenant_deployment_id}-${local.random_id}-${local.regions[count.index]}"
  display_name = "app${var.application_name}-monitoring-service-${var.tenant_deployment_id}-${local.random_id}"
  project      = local.project.project_id

  user_labels = {
    app = "app${var.application_name}${var.tenant_deployment_id}"
  }

  basic_service {
    service_type  = "CLOUD_RUN"
    service_labels = {
      location = local.regions[count.index]
      service_name = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    }
  }

  depends_on = [
    google_cloud_scheduler_job.backup,
    google_cloud_run_v2_service.app_service,
  ]
}

# Define a Service Level Objective (SLO) for Cloud Run service latency.
resource "google_monitoring_slo" "latency_slo" {
  count = (var.configure_monitoring && var.configure_environment) ? length(local.regions) : 0
  service      = google_monitoring_service.cloud_run[count.index].service_id
  slo_id       = "app${var.application_name}-latency-slo-${var.tenant_deployment_id}-${local.random_id}"
  display_name = "app${var.application_name}-latency-slo-${var.tenant_deployment_id}-${local.random_id}"
  goal         = 0.95
  project      = local.project.project_id
  calendar_period = "DAY"

  request_based_sli {
    distribution_cut {
      distribution_filter = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\""
      range {
        min = 0
        max = 5000
      }
    }
  }

  depends_on = [
    google_monitoring_service.cloud_run,
    google_cloud_run_v2_service.app_service,
  ]
}

# Define a Service Level Objective (SLO) for Cloud Run service availability.
resource "google_monitoring_slo" "availability_slo" {
  count = (var.configure_monitoring && var.configure_environment) ? length(local.regions) : 0
  service      = google_monitoring_service.cloud_run[count.index].service_id
  slo_id       = "app${var.application_name}-availability-slo-${var.tenant_deployment_id}-${local.random_id}"
  display_name = "app${var.application_name}-availability-slo-${var.tenant_deployment_id}-${local.random_id}"
  goal         = 0.95
  project      = local.project.project_id
  calendar_period = "DAY"

  request_based_sli {
    good_total_ratio {
      good_service_filter = "metric.type=\"run.googleapis.com/request_count\" AND resource.type=\"cloud_run_revision\" AND metric.label.response_code_class=\"2xx\""
      bad_service_filter  = "metric.type=\"run.googleapis.com/request_count\" AND resource.type=\"cloud_run_revision\" AND NOT metric.label.response_code_class=\"2xx\""
    }
  }

  depends_on = [
    google_monitoring_service.cloud_run,
    google_cloud_run_v2_service.app_service,
  ]
}

# Define an uptime check configuration for monitoring service availability.
resource "google_monitoring_uptime_check_config" "https" {
  count = (var.configure_monitoring && var.configure_environment) ? length(local.regions) : 0
  project = local.project.project_id
  display_name = "app${var.application_name}-uptime-check-config-${var.tenant_deployment_id}-${local.random_id}"
  timeout = "60s"
  period = "900s"

  http_check {
    path = "/web/health"
    port = "443"
    use_ssl = true
    validate_ssl = false
  }

  monitored_resource {
    type = "cloud_run_revision"
    labels = {
      project_id = local.project.project_id
      service_name = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
      location = local.regions[count.index]
    }
  }

  depends_on = [
    time_sleep.app_service,
    google_cloud_run_v2_service.app_service,
 ]
}

resource "time_sleep" "app_service" {
  create_duration = "60s"
  depends_on = [
    google_cloud_run_v2_service.app_service,
  ]
}

