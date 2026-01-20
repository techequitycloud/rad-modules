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
# Notification Channels
#########################################################################

resource "google_monitoring_notification_channel" "email" {
  count = local.configure_monitoring && length(var.trusted_users) > 0 ? length(var.trusted_users) : 0

  project      = local.project.project_id
  display_name = "${local.service_name}-notification-${count.index}"
  type         = "email"
  labels = {
    email_address = var.trusted_users[count.index]
  }
  force_delete = true
}

#########################################################################
# Alert Policies
#########################################################################

# CPU utilization alert
resource "google_monitoring_alert_policy" "cpu_alert" {
  count = local.configure_monitoring && length(var.trusted_users) > 0 ? 1 : 0

  project      = local.project.project_id
  display_name = "${local.service_name}-cpu-utilization-alert"
  documentation {
    content = "The CPU utilization has exceeded 90% for over 1 minute."
  }
  combiner = "OR"

  conditions {
    display_name = "CPU Utilization > 90%"
    condition_threshold {
      comparison      = "COMPARISON_GT"
      duration        = "60s"
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${local.service_name}\" AND metric.type = \"run.googleapis.com/container/cpu/utilizations\""
      threshold_value = "0.9"
      trigger {
        count = "1"
      }
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_99"
      }
    }
  }

  alert_strategy {
    notification_channel_strategy {
      renotify_interval          = "1800s"
      notification_channel_names = google_monitoring_notification_channel.email[*].name
    }
  }

  notification_channels = google_monitoring_notification_channel.email[*].name

  user_labels = merge(
    local.common_labels,
    {
      severity = "warning"
    }
  )
}

# Memory utilization alert
resource "google_monitoring_alert_policy" "memory_alert" {
  count = local.configure_monitoring && length(var.trusted_users) > 0 ? 1 : 0

  project      = local.project.project_id
  display_name = "${local.service_name}-memory-utilization-alert"
  documentation {
    content = "The memory utilization has exceeded 90% for over 1 minute."
  }
  combiner = "OR"

  conditions {
    display_name = "Memory Utilization > 90%"
    condition_threshold {
      comparison      = "COMPARISON_GT"
      duration        = "60s"
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${local.service_name}\" AND metric.type = \"run.googleapis.com/container/memory/utilizations\""
      threshold_value = "0.9"
      trigger {
        count = "1"
      }
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_99"
      }
    }
  }

  alert_strategy {
    notification_channel_strategy {
      renotify_interval          = "1800s"
      notification_channel_names = google_monitoring_notification_channel.email[*].name
    }
  }

  notification_channels = google_monitoring_notification_channel.email[*].name

  user_labels = merge(
    local.common_labels,
    {
      severity = "warning"
    }
  )
}

# Custom alert policies from user configuration
resource "google_monitoring_alert_policy" "custom_alerts" {
  for_each = local.configure_monitoring ? { for idx, policy in var.alert_policies : policy.name => policy } : {}

  project      = local.project.project_id
  display_name = "${local.service_name}-${each.value.name}"
  combiner     = "OR"

  conditions {
    display_name = each.value.name
    condition_threshold {
      comparison      = each.value.comparison
      duration        = "${each.value.duration_seconds}s"
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${local.service_name}\" AND metric.type = \"${each.value.metric_type}\""
      threshold_value = each.value.threshold_value
      trigger {
        count = "1"
      }
      aggregations {
        alignment_period   = each.value.aggregation_period
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = length(var.trusted_users) > 0 ? google_monitoring_notification_channel.email[*].name : []

  user_labels = local.common_labels
}

#########################################################################
# Monitoring Service
#########################################################################

resource "google_monitoring_service" "cloud_run" {
  count = local.configure_monitoring && var.configure_environment ? length(local.regions) : 0

  service_id   = "${local.service_name}-monitoring-${local.regions[count.index]}"
  display_name = "${local.service_name}-monitoring"
  project      = local.project.project_id

  user_labels = merge(
    local.common_labels,
    {
      app = local.application_name
    }
  )

  basic_service {
    service_type = "CLOUD_RUN"
    service_labels = {
      location     = local.regions[count.index]
      service_name = local.service_name
    }
  }

  depends_on = [
    google_cloud_run_v2_service.app_service,
  ]
}

#########################################################################
# Service Level Objectives (SLOs)
#########################################################################

# Latency SLO
resource "google_monitoring_slo" "latency_slo" {
  count = local.configure_monitoring && var.configure_environment ? length(local.regions) : 0

  service      = google_monitoring_service.cloud_run[count.index].service_id
  slo_id       = "${local.service_name}-latency-slo"
  display_name = "${local.service_name} Latency SLO"
  goal         = 0.95
  project      = local.project.project_id
  calendar_period = "DAY"

  request_based_sli {
    distribution_cut {
      distribution_filter = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\""
      range {
        min = 0
        max = 5000 # 5 seconds
      }
    }
  }

  depends_on = [
    google_monitoring_service.cloud_run,
    google_cloud_run_v2_service.app_service,
  ]
}

# Availability SLO
resource "google_monitoring_slo" "availability_slo" {
  count = local.configure_monitoring && var.configure_environment ? length(local.regions) : 0

  service      = google_monitoring_service.cloud_run[count.index].service_id
  slo_id       = "${local.service_name}-availability-slo"
  display_name = "${local.service_name} Availability SLO"
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

#########################################################################
# Uptime Checks
#########################################################################

resource "google_monitoring_uptime_check_config" "https" {
  count = local.uptime_check_enabled && var.configure_environment ? length(local.regions) : 0

  project      = local.project.project_id
  display_name = "${local.service_name}-uptime-check"
  timeout      = var.uptime_check_config.timeout
  period       = var.uptime_check_config.check_interval

  http_check {
    path         = var.uptime_check_config.path
    port         = "443"
    use_ssl      = true
    validate_ssl = false
  }

  monitored_resource {
    type = "cloud_run_revision"
    labels = {
      project_id   = local.project.project_id
      service_name = local.service_name
      location     = local.regions[count.index]
    }
  }

  depends_on = [
    time_sleep.app_service,
    google_cloud_run_v2_service.app_service,
  ]
}

# Wait for service to be ready before creating uptime checks
resource "time_sleep" "app_service" {
  count = var.configure_environment ? 1 : 0

  create_duration = "60s"

  depends_on = [
    google_cloud_run_v2_service.app_service,
  ]
}
