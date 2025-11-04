/**
 * Copyright 2023 Google LLC
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

/**
# Configure alert policy for compute engine instances
resource "google_monitoring_alert_policy" "alert_policy" {
  count   = var.enable_monitoring ? 1 : 0
  project = local.project.project_id
  display_name = "CPU Utilization > 50%"
  documentation {
    content = "The $${metric.display_name} of the $${resource.type} $${resource.label.instance_id} in $${resource.project} has exceeded 50% for over 1 minute."
  }
  combiner     = "OR"
  conditions {
    display_name = "Condition 1"
    condition_threshold {
        comparison = "COMPARISON_GT"
        duration = "60s"
        filter = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
        threshold_value = "0.5"
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
  count   = var.enable_monitoring ? 1 : 0
  # Specifies the project in which the notification channel is created.
  project = local.project.project_id
  # Human-readable name for the notification channel.
  display_name = "Notification Channel"
  # Type of the notification channel (email in this case).
  type         = "email"
  labels = {
    # Email address where notifications will be sent.
    email_address = tolist(var.trusted_users)[0]
  }
  # Whether to force delete the notification channel when it's removed from Terraform configuration.
  force_delete = true

  # Dependencies to ensure resources are created in the correct order
  # depends_on = [
  #   null_resource.get_external_ip,
  #   time_sleep.wait_120_seconds
  # ]
}
*/

#########################################################################
# Configure resources
#########################################################################

resource "google_monitoring_service" "accounts-db" {
  count   = var.enable_monitoring ? 1 : 0
  service_id   = "accounts-db"
  display_name = "accounts-db"
  project      = local.project.project_id

  basic_service {
    service_type = "GKE_SERVICE"

    service_labels = {
      cluster_name   = "${var.gke_cluster}"
      location       = "${var.region}"
      namespace_name = "bank-of-anthos"
      project_id     = local.project.project_id
      service_name   = "accounts-db"
    }
  }
}

resource "google_monitoring_slo" "accounts-db_slo_limit_utilization" {
  count   = var.enable_monitoring ? 1 : 0
  project       = local.project.project_id
  service       = google_monitoring_service.accounts-db[count.index].service_id
  display_name  = "95.0% - CPU Limit Utilization Metric - Calendar day"
  goal          = 0.95
  calendar_period = "DAY"

  windows_based_sli {
    window_period = "300s"

    metric_sum_in_range {
      time_series = "metric.type=\"kubernetes.io/container/cpu/limit_utilization\" resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"bank-of-anthos\" AND resource.label.\"cluster_name\"=\"${var.gke_cluster}\""
      range {
        min = -9007199254740991
        max = 1
      }
    }
  }
}

resource "google_monitoring_service" "balancereader" {
  count   = var.enable_monitoring ? 1 : 0
  service_id   = "balancereader"
  display_name = "balancereader"
  project      = local.project.project_id

  basic_service {
    service_type = "GKE_SERVICE"

    service_labels = {
      cluster_name   = "${var.gke_cluster}"
      location       = "${var.region}"
      namespace_name = "bank-of-anthos"
      project_id     = local.project.project_id
      service_name   = "balancereader"
    }
  }
}

resource "google_monitoring_slo" "balancereader_slo_limit_utilization" {
  count   = var.enable_monitoring ? 1 : 0
  project       = local.project.project_id
  service       = google_monitoring_service.balancereader[count.index].service_id
  display_name  = "95.0% - CPU Limit Utilization Metric - Calendar day"
  goal          = 0.95
  calendar_period = "DAY"

  windows_based_sli {
    window_period = "300s"

    metric_sum_in_range {
      time_series = "metric.type=\"kubernetes.io/container/cpu/limit_utilization\" resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"bank-of-anthos\" AND resource.label.\"cluster_name\"=\"${var.gke_cluster}\""
      range {
        min = -9007199254740991
        max = 1
      }
    }
  }
}

resource "google_monitoring_service" "contacts" {
  count   = var.enable_monitoring ? 1 : 0
  service_id   = "contacts"
  display_name = "contacts"
  project      = local.project.project_id

  basic_service {
    service_type = "GKE_SERVICE"

    service_labels = {
      cluster_name   = "${var.gke_cluster}"
      location       = "${var.region}"
      namespace_name = "bank-of-anthos"
      project_id     = local.project.project_id
      service_name   = "contacts"
    }
  }
}

resource "google_monitoring_slo" "contacts_slo_limit_utilization" {
  count   = var.enable_monitoring ? 1 : 0
  project       = local.project.project_id
  service       = google_monitoring_service.contacts[count.index].service_id
  display_name  = "95.0% - CPU Limit Utilization Metric - Calendar day"
  goal          = 0.95
  calendar_period = "DAY"

  windows_based_sli {
    window_period = "300s"

    metric_sum_in_range {
      time_series = "metric.type=\"kubernetes.io/container/cpu/limit_utilization\" resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"bank-of-anthos\" AND resource.label.\"cluster_name\"=\"${var.gke_cluster}\""
      range {
        min = -9007199254740991
        max = 1
      }
    }
  }
}

resource "google_monitoring_service" "frontend" {
  count   = var.enable_monitoring ? 1 : 0
  service_id   = "frontend"
  display_name = "frontend"
  project      = local.project.project_id

  basic_service {
    service_type = "GKE_SERVICE"

    service_labels = {
      cluster_name   = "${var.gke_cluster}"
      location       = "${var.region}"
      namespace_name = "bank-of-anthos"
      project_id     = local.project.project_id
      service_name   = "frontend"
    }
  }
}

resource "google_monitoring_slo" "frontend_slo_limit_utilization" {
  count   = var.enable_monitoring ? 1 : 0
  project       = local.project.project_id
  service       = google_monitoring_service.frontend[count.index].service_id
  display_name  = "95.0% - CPU Limit Utilization Metric - Calendar day"
  goal          = 0.95
  calendar_period = "DAY"

  windows_based_sli {
    window_period = "300s"

    metric_sum_in_range {
      time_series = "metric.type=\"kubernetes.io/container/cpu/limit_utilization\" resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"bank-of-anthos\" AND resource.label.\"cluster_name\"=\"${var.gke_cluster}\""
      range {
        min = -9007199254740991
        max = 1
      }
    }
  }
}

resource "google_monitoring_service" "ledger-db" {
  count   = var.enable_monitoring ? 1 : 0
  service_id   = "ledger-db"
  display_name = "ledger-db"
  project      = local.project.project_id

  basic_service {
    service_type = "GKE_SERVICE"

    service_labels = {
      cluster_name   = "${var.gke_cluster}"
      location       = "${var.region}"
      namespace_name = "bank-of-anthos"
      project_id     = local.project.project_id
      service_name   = "ledger-db"
    }
  }
}

resource "google_monitoring_slo" "ledger-db_slo_limit_utilization" {
  count   = var.enable_monitoring ? 1 : 0
  project       = local.project.project_id
  service       = google_monitoring_service.ledger-db[count.index].service_id
  display_name  = "95.0% - CPU Limit Utilization Metric - Calendar day"
  goal          = 0.95
  calendar_period = "DAY"

  windows_based_sli {
    window_period = "300s"

    metric_sum_in_range {
      time_series = "metric.type=\"kubernetes.io/container/cpu/limit_utilization\" resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"bank-of-anthos\" AND resource.label.\"cluster_name\"=\"${var.gke_cluster}\""
      range {
        min = -9007199254740991
        max = 1
      }
    }
  }
}

resource "google_monitoring_service" "ledgerwriter" {
  count   = var.enable_monitoring ? 1 : 0
  service_id   = "ledgerwriter"
  display_name = "ledgerwriter"
  project      = local.project.project_id

  basic_service {
    service_type = "GKE_SERVICE"

    service_labels = {
      cluster_name   = "${var.gke_cluster}"
      location       = "${var.region}"
      namespace_name = "bank-of-anthos"
      project_id     = local.project.project_id
      service_name   = "ledgerwriter"
    }
  }
}

resource "google_monitoring_slo" "ledgerwriter_slo_limit_utilization" {
  count   = var.enable_monitoring ? 1 : 0
  project       = local.project.project_id
  service       = google_monitoring_service.ledgerwriter[count.index].service_id
  display_name  = "95.0% - CPU Limit Utilization Metric - Calendar day"
  goal          = 0.95
  calendar_period = "DAY"

  windows_based_sli {
    window_period = "300s"

    metric_sum_in_range {
      time_series = "metric.type=\"kubernetes.io/container/cpu/limit_utilization\" resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"bank-of-anthos\" AND resource.label.\"cluster_name\"=\"${var.gke_cluster}\""
      range {
        min = -9007199254740991
        max = 1
      }
    }
  }
}

resource "google_monitoring_service" "loadgenerator" {
  count   = var.enable_monitoring ? 1 : 0
  service_id   = "loadgenerator"
  display_name = "loadgenerator"
  project      = local.project.project_id

  basic_service {
    service_type = "GKE_SERVICE"

    service_labels = {
      cluster_name   = "${var.gke_cluster}"
      location       = "${var.region}"
      namespace_name = "bank-of-anthos"
      project_id     = local.project.project_id
      service_name   = "loadgenerator"
    }
  }
}

resource "google_monitoring_slo" "loadgenerator_slo_limit_utilization" {
  count   = var.enable_monitoring ? 1 : 0
  project       = local.project.project_id
  service       = google_monitoring_service.loadgenerator[count.index].service_id
  display_name  = "95.0% - CPU Limit Utilization Metric - Calendar day"
  goal          = 0.95
  calendar_period = "DAY"

  windows_based_sli {
    window_period = "300s"

    metric_sum_in_range {
      time_series = "metric.type=\"kubernetes.io/container/cpu/limit_utilization\" resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"bank-of-anthos\" AND resource.label.\"cluster_name\"=\"${var.gke_cluster}\""
      range {
        min = -9007199254740991
        max = 1
      }
    }
  }
}

resource "google_monitoring_service" "transactionhistory" {
  count   = var.enable_monitoring ? 1 : 0
  service_id   = "transactionhistory"
  display_name = "transactionhistory"
  project      = local.project.project_id

  basic_service {
    service_type = "GKE_SERVICE"

    service_labels = {
      cluster_name   = "${var.gke_cluster}"
      location       = "${var.region}"
      namespace_name = "bank-of-anthos"
      project_id     = local.project.project_id
      service_name   = "transactionhistory"
    }
  }
}

resource "google_monitoring_slo" "transactionhistory_slo_limit_utilization" {
  count   = var.enable_monitoring ? 1 : 0
  project       = local.project.project_id
  service       = google_monitoring_service.transactionhistory[count.index].service_id
  display_name  = "95.0% - CPU Limit Utilization Metric - Calendar day"
  goal          = 0.95
  calendar_period = "DAY"

  windows_based_sli {
    window_period = "300s"

    metric_sum_in_range {
      time_series = "metric.type=\"kubernetes.io/container/cpu/limit_utilization\" resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"bank-of-anthos\" AND resource.label.\"cluster_name\"=\"${var.gke_cluster}\""
      range {
        min = -9007199254740991
        max = 1
      }
    }
  }

  # Dependencies to ensure resources are created in the correct order
  # depends_on = [
  #   null_resource.get_external_ip,
  #   time_sleep.wait_120_seconds
  # ]
}

resource "google_monitoring_service" "userservice" {
  count   = var.enable_monitoring ? 1 : 0
  service_id   = "userservice"
  display_name = "userservice"
  project      = local.project.project_id

  basic_service {
    service_type = "GKE_SERVICE"

    service_labels = {
      cluster_name   = "${var.gke_cluster}"
      location       = "${var.region}"
      namespace_name = "bank-of-anthos"
      project_id     = local.project.project_id
      service_name   = "userservice"
    }
  }

  # Dependencies to ensure resources are created in the correct order
  # depends_on = [
  #   null_resource.get_external_ip,
  #   time_sleep.wait_120_seconds
  # ]
}

resource "google_monitoring_slo" "userservice_slo_limit_utilization" {
  count   = var.enable_monitoring ? 1 : 0
  project       = local.project.project_id
  service       = google_monitoring_service.userservice[count.index].service_id
  display_name  = "95.0% - CPU Limit Utilization Metric - Calendar day"
  goal          = 0.95
  calendar_period = "DAY"

  windows_based_sli {
    window_period = "300s"

    metric_sum_in_range {
      time_series = "metric.type=\"kubernetes.io/container/cpu/limit_utilization\" resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"bank-of-anthos\" AND resource.label.\"cluster_name\"=\"${var.gke_cluster}\""
      range {
        min = -9007199254740991
        max = 1
      }
    }
  }

  # Dependencies to ensure resources are created in the correct order
  # depends_on = [
  #   null_resource.get_external_ip,
  #   time_sleep.wait_120_seconds
  # ]
}

/**
resource "google_monitoring_alert_policy" "bank-of-anthos_alert_policy" {
  count   = var.enable_monitoring ? 1 : 0
  display_name = "SLO Alert Policy"
  project      = local.project.project_id
  combiner     = "OR"

  conditions {
    display_name = "bank-of-anthos SLO Violation"
    condition_threshold {
      filter          = "metric.type=\"kubernetes.io/container/cpu/request_utilization\" AND resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"bank-of-anthos\" AND resource.label.\"cluster_name\"=\"${var.gke_cluster}\""
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

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    null_resource.get_external_ip,
    time_sleep.wait_120_seconds
  ]
}

# Define an uptime check configuration for monitoring service availability.
resource "google_monitoring_uptime_check_config" "bank-of-anthos_https" {
  count   = var.enable_monitoring ? 1 : 0
  # Specifies the project in which the uptime check is created.
  project = local.project.project_id
  # Human-readable name for the uptime check configuration.
  display_name = "boa-https-uptime-check"
  # The maximum amount of time to wait for a response (60 seconds).
  timeout = "60s"

  # Configuration for the HTTP check to perform.
  http_check {
    # The path to check on the host.
    path = "/"
    # The port on which to perform the check (443 for HTTPS).
    port = "443"
    # Indicates that SSL should be used for the check.
    use_ssl = true
    # Indicates that the SSL certificate should be validated.
    validate_ssl = true
  }

  # Specifies the monitored resource details.
  monitored_resource {
    # Type of the monitored resource (uptime URL).
    type = "uptime_url"
    labels = {
      # Project ID for the monitored resource.
      project_id = local.project.project_id
      # Assuming var.app_name contains the full URL, and you want to extract the hostname
      host = "boa.${google_compute_global_address.glb.address}.sslip.io"
    }
  }

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    null_resource.get_external_ip,
    time_sleep.wait_120_seconds
  ]
}
*/
