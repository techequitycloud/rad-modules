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
/**
resource "google_monitoring_alert_policy" "alert_policy" {
  count   = var.configure_monitoring ? 1 : 0
  project = local.project.project_id
  display_name = "app${var.application_name}-alert-policy-${var.tenant_deployment_id}-${local.random_id}"
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
  count   = var.configure_monitoring ? 1 : 0
  project = local.project.project_id
  display_name = "app${var.application_name}-notification-channel-${var.tenant_deployment_id}-${local.random_id}"
  type         = "email"
  labels = {
    email_address = tolist(var.trusted_users)[0] # The first email
  }
  force_delete = true
}
*/

#########################################################################
# Configure Dev resources
#########################################################################

resource "google_monitoring_service" "dev_service" {
  count   = var.configure_monitoring && var.configure_development_environment ? 1 : 0
  service_id   = "app${var.application_name}dev-monitoring-service-${var.tenant_deployment_id}-${local.random_id}"
  display_name = "app${var.application_name}dev-monitoring-service-${var.tenant_deployment_id}-${local.random_id}"
  project      = local.project.project_id

  basic_service {
    service_type = "GKE_SERVICE"

    service_labels = {
      cluster_name   = "${local.gke_cluster_name}"
      location       = "${local.gke_cluster_region}"
      namespace_name = "${var.application_name}${var.tenant_deployment_id}dev"
      project_id     = local.project.project_id
      service_name   = "app${var.application_name}${local.random_id}dev"
    }
  }
}

resource "google_monitoring_slo" "dev_slo_limit_utilization" {
  count   = var.configure_monitoring && var.configure_development_environment ? 1 : 0
  project       = local.project.project_id
  service       = google_monitoring_service.dev_service[count.index].service_id
  display_name = "app${var.application_name}dev-cpu-limit-utilization-${var.tenant_deployment_id}-${local.random_id}"
  goal          = 0.95
  calendar_period = "DAY"

  windows_based_sli {
    window_period = "300s"

    metric_sum_in_range {
      time_series = "metric.type=\"kubernetes.io/container/cpu/limit_utilization\" resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"${var.application_name}${var.tenant_deployment_id}dev\" AND resource.label.\"cluster_name\"=\"${local.gke_cluster_name}\""
      range {
        min = -9007199254740991
        max = 1
      }
    }
  }
}

/**
resource "google_monitoring_alert_policy" "dev_alert_policy" {
  count   = var.configure_monitoring && var.configure_development_environment ? 1 : 0
  display_name = "app${var.application_name}dev-cpu-request-utilization-${var.tenant_deployment_id}-${local.random_id}"
  project      = local.project.project_id
  combiner     = "OR"

  conditions {
    display_name = "app${var.application_name}${local.random_id}dev SLO Violation"
    condition_threshold {
      filter          = "metric.type=\"kubernetes.io/container/cpu/request_utilization\" AND resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"${var.application_name}${var.tenant_deployment_id}dev\" AND resource.label.\"cluster_name\"=\"${local.gke_cluster_name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.7 # Example threshold; adjust as needed
      duration        = "60s"

      aggregations {
        alignment_period  = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email[count.index].name]
}

# Define an uptime check configuration for monitoring service availability.
resource "google_monitoring_uptime_check_config" "dev_https" {
  count   = var.configure_monitoring && var.configure_development_environment ? 1 : 0
  project = local.project.project_id
  display_name = "app${var.application_name}dev-uptime-check-config-${var.tenant_deployment_id}-${local.random_id}"
  timeout = "60s"

  http_check {
    path = "/"
    port = "443"
    use_ssl = true
    validate_ssl = false
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = local.project.project_id
      host = "app${var.application_name}${local.random_id}dev.${google_compute_global_address.dev[count.index].address}.sslip.io"
    }
  }

  depends_on = [google_compute_global_address.dev]  
}
*/

#########################################################################
# Configure QA resources
#########################################################################

resource "google_monitoring_service" "qa_service" {
  count   = var.configure_monitoring && var.configure_nonproduction_environment ? 1 : 0
  service_id   = "app${var.application_name}qa-monitoring-service-${var.tenant_deployment_id}-${local.random_id}"
  display_name = "app${var.application_name}qa-monitoring-service-${var.tenant_deployment_id}-${local.random_id}"
  project      = local.project.project_id

  basic_service {
    service_type = "GKE_SERVICE"

    service_labels = {
      cluster_name   = "${local.gke_cluster_name}"
      location       = "${local.gke_cluster_region}"
      namespace_name = "${var.application_name}${var.tenant_deployment_id}qa"
      project_id     = local.project.project_id
      service_name   = "app${var.application_name}${local.random_id}qa"
    }
  }
}

resource "google_monitoring_slo" "qa_slo_limit_utilization" {
  count   = var.configure_monitoring && var.configure_nonproduction_environment ? 1 : 0
  project       = local.project.project_id
  service       = google_monitoring_service.qa_service[count.index].service_id
  display_name = "app${var.application_name}qa-cpu-limit-utilization-${var.tenant_deployment_id}-${local.random_id}"
  goal          = 0.95
  calendar_period = "DAY"

  windows_based_sli {
    window_period = "300s"

    metric_sum_in_range {
      time_series = "metric.type=\"kubernetes.io/container/cpu/limit_utilization\" resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"${var.application_name}${var.tenant_deployment_id}qa\" AND resource.label.\"cluster_name\"=\"${local.gke_cluster_name}\""
      range {
        min = -9007199254740991
        max = 1
      }
    }
  }
}

/**
resource "google_monitoring_alert_policy" "qa_alert_policy" {
  count   = var.configure_monitoring && var.configure_nonproduction_environment ? 1 : 0
  display_name = "app${var.application_name}qa-cpu-request-utilization-${var.tenant_deployment_id}-${local.random_id}"
  project      = local.project.project_id
  combiner     = "OR"

  conditions {
    display_name = "app${var.application_name}${local.random_id}qa SLO Violation"
    condition_threshold {
      filter          = "metric.type=\"kubernetes.io/container/cpu/request_utilization\" AND resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"${var.application_name}${var.tenant_deployment_id}qa\" AND resource.label.\"cluster_name\"=\"${local.gke_cluster_name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.7 # Example threshold; adjust as needed
      duration        = "60s"

      aggregations {
        alignment_period  = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email[count.index].name]
}

# Define an uptime check configuration for monitoring service availability.
resource "google_monitoring_uptime_check_config" "qa_https" {
  count   = var.configure_monitoring && var.configure_nonproduction_environment ? 1 : 0
  project = local.project.project_id
  display_name = "app${var.application_name}qa-uptime-check-config-${var.tenant_deployment_id}-${local.random_id}"
  timeout = "60s"

  http_check {
    path = "/"
    port = "443"
    use_ssl = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = local.project.project_id
      host = "app${var.application_name}${local.random_id}qa.${google_compute_global_address.qa[count.index].address}.sslip.io"
    }
  }
  
  depends_on = [google_compute_global_address.qa] 
} */

#########################################################################
# Configure Prod resources
#########################################################################

resource "google_monitoring_service" "prod_service" {
  count   = var.configure_monitoring && var.configure_production_environment ? 1 : 0
  service_id   = "app${var.application_name}prod-monitoring-service-${var.tenant_deployment_id}-${local.random_id}"
  display_name = "app${var.application_name}prod-monitoring-service-${var.tenant_deployment_id}-${local.random_id}"
  project      = local.project.project_id

  basic_service {
    service_type = "GKE_SERVICE"

    service_labels = {
      cluster_name   = "${local.gke_cluster_name}"
      location       = "${local.gke_cluster_region}"
      namespace_name = "${var.application_name}${var.tenant_deployment_id}prod"
      project_id     = local.project.project_id
      service_name   = "app${var.application_name}${local.random_id}prod"
    }
  }
}

resource "google_monitoring_slo" "prod_slo_limit_utilization" {
  count   = var.configure_monitoring && var.configure_production_environment ? 1 : 0
  project       = local.project.project_id
  service       = google_monitoring_service.prod_service[count.index].service_id
  display_name = "app${var.application_name}prod-cpu-limit-utilization-${var.tenant_deployment_id}-${local.random_id}"
  goal          = 0.95
  calendar_period = "DAY"

  windows_based_sli {
    window_period = "300s"

    metric_sum_in_range {
      time_series = "metric.type=\"kubernetes.io/container/cpu/limit_utilization\" resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"${var.application_name}${var.tenant_deployment_id}prod\" AND resource.label.\"cluster_name\"=\"${local.gke_cluster_name}\""
      range {
        min = -9007199254740991
        max = 1
      }
    }
  }
}

/**
resource "google_monitoring_alert_policy" "prod_alert_policy" {
  count   = var.configure_monitoring && var.configure_production_environment ? 1 : 0
  display_name = "app${var.application_name}prod-cpu-request-utilization-${var.tenant_deployment_id}-${local.random_id}"
  project      = local.project.project_id
  combiner     = "OR"

  conditions {
    display_name = "app${var.application_name}${local.random_id}prod SLO Violation"
    condition_threshold {
      filter          = "metric.type=\"kubernetes.io/container/cpu/request_utilization\" AND resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"${var.application_name}${var.tenant_deployment_id}prod\" AND resource.label.\"cluster_name\"=\"${local.gke_cluster_name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.7 # Example threshold; adjust as needed
      duration        = "60s"

      aggregations {
        alignment_period  = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email[count.index].name]
}

# Define an uptime check configuration for monitoring service availability.
resource "google_monitoring_uptime_check_config" "prod_https" {
  count   = var.configure_monitoring && var.configure_production_environment ? 1 : 0
  project = local.project.project_id
  display_name = "app${var.application_name}prod-uptime-check-config-${var.tenant_deployment_id}-${local.random_id}"
  timeout = "60s"

  http_check {
    path = "/"
    port = "443"
    use_ssl = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = local.project.project_id
      host = "app${var.application_name}${local.random_id}prod.${google_compute_global_address.prod[count.index].address}.sslip.io"
    }
  }
  
  depends_on = [google_compute_global_address.prod]  
}
*/

/**
resource "google_monitoring_alert_policy" "uptime_check_alert" {
  count   = var.configure_monitoring ? 1 : 0
  project = local.project.project_id
  display_name = "app${var.application_name}-uptime-check-alert-policy-${var.tenant_deployment_id}-${local.random_id}"

  combiner = "OR"  # Options are "AND" or "OR"

  conditions {
    display_name = "Uptime Check Condition"
    condition_threshold {
      filter = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\""

      comparison = "COMPARISON_LT"
      threshold_value = 1
      duration = "60s"
      aggregations {
        alignment_period = "60s"
        per_series_aligner = "ALIGN_NONE"
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email[count.index].name,
  ]

  depends_on = [
    module.deploy_dev_ingress,
    module.deploy_qa_ingress,
    module.deploy_prod_ingress,
  ]  
} **/
