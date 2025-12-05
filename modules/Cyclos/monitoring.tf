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
# Configure Dev resources
#########################################################################
# Define a service for Cloud Run to be monitored.
resource "google_monitoring_service" "dev_cloud_run" {
  count =  (var.configure_monitoring && var.configure_development_environment) ? 1 : 0
  service_id   = "app${var.application_name}dev-monitoring-service-${var.tenant_deployment_id}-${local.random_id}-${local.region}"
  display_name = "app${var.application_name}dev-monitoring-service-${var.tenant_deployment_id}-${local.random_id}"
  project      = local.project.project_id

  user_labels = {
    app = "app${var.application_name}${var.tenant_deployment_id}"
    env = "dev"
  }

  basic_service {
    service_type  = "CLOUD_RUN"
    service_labels = {
      location = local.region
      service_name = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
    }
  }

  depends_on = [
    google_cloud_scheduler_job.dev_backup,
    google_cloud_run_v2_service.dev_app_service,
  ]
}

# Define a Service Level Objective (SLO) for Cloud Run service latency.
resource "google_monitoring_slo" "dev_latency_slo" {
  count = (var.configure_monitoring && var.configure_development_environment) ? 1 : 0
  service      = google_monitoring_service.dev_cloud_run[count.index].service_id
  slo_id       = "app${var.application_name}dev-latency-slo-${var.tenant_deployment_id}-${local.random_id}"
  display_name = "app${var.application_name}dev-latency-slo-${var.tenant_deployment_id}-${local.random_id}"
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
    google_monitoring_service.dev_cloud_run,
    google_cloud_run_v2_service.dev_app_service,
  ]
}

# Define a Service Level Objective (SLO) for Cloud Run service availability.
resource "google_monitoring_slo" "dev_availability_slo" {
  count = (var.configure_monitoring && var.configure_development_environment) ? 1 : 0
  service      = google_monitoring_service.dev_cloud_run[count.index].service_id
  slo_id       = "app${var.application_name}dev-availability-slo-${var.tenant_deployment_id}-${local.random_id}"
  display_name = "app${var.application_name}dev-availability-slo-${var.tenant_deployment_id}-${local.random_id}"
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
    google_monitoring_service.dev_cloud_run,
    google_cloud_run_v2_service.dev_app_service,
  ]
}

# Define an uptime check configuration for monitoring service availability.
resource "google_monitoring_uptime_check_config" "dev_https" {
  count = (var.configure_monitoring && var.configure_development_environment) ? length(local.regions) : 0
  project = local.project.project_id
  display_name = "app${var.application_name}dev-uptime-check-config-${var.tenant_deployment_id}-${local.random_id}"
  timeout = "60s"
  period = "900s"

  http_check {
    path = "/api"
    port = "443"
    use_ssl = true
    validate_ssl = false
  }

  monitored_resource {
    type = "cloud_run_revision"
    labels = {
      project_id = local.project.project_id
      service_name = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
      location = local.region
    }
  }

  depends_on = [
    time_sleep.dev_app_service,
    google_cloud_run_v2_service.dev_app_service,
  ]
}

resource "time_sleep" "dev_app_service" {
  create_duration = "60s"
  depends_on = [
    google_cloud_run_v2_service.dev_app_service,
  ]
}

#########################################################################
# Configure QA resources
#########################################################################

# Define a service for Cloud Run to be monitored.
resource "google_monitoring_service" "qa_cloud_run" {
  count = (var.configure_monitoring && var.configure_nonproduction_environment) ? 1 : 0
  service_id   = "app${var.application_name}qa-monitoring-service-${var.tenant_deployment_id}-${local.random_id}-${local.region}"
  display_name = "app${var.application_name}qa-monitoring-service-${var.tenant_deployment_id}-${local.random_id}"
  project      = local.project.project_id

  user_labels = {
    app = "app${var.application_name}${var.tenant_deployment_id}"
    env = "qa"
  }

  basic_service {
    service_type  = "CLOUD_RUN"
    service_labels = {
      location = local.region
      service_name = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
    }
  }

  depends_on = [
    google_cloud_scheduler_job.qa_backup,
    google_cloud_run_v2_service.qa_app_service,
  ]
}

# Define a Service Level Objective (SLO) for Cloud Run service latency.
resource "google_monitoring_slo" "qa_latency_slo" {
  count = (var.configure_monitoring && var.configure_nonproduction_environment) ? 1 : 0
  service      = google_monitoring_service.qa_cloud_run[count.index].service_id
  slo_id       = "app${var.application_name}qa-latency-slo-${var.tenant_deployment_id}-${local.random_id}"
  display_name = "app${var.application_name}qa-latency-slo-${var.tenant_deployment_id}-${local.random_id}"
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
    google_monitoring_service.qa_cloud_run,
    google_cloud_run_v2_service.qa_app_service,
  ]
}

# Define a Service Level Objective (SLO) for Cloud Run service availability.
resource "google_monitoring_slo" "qa_availability_slo" {
  count = (var.configure_monitoring && var.configure_nonproduction_environment) ? 1 : 0
  service      = google_monitoring_service.qa_cloud_run[count.index].service_id
  slo_id       = "app${var.application_name}qa-availability-slo-${var.tenant_deployment_id}-${local.random_id}"
  display_name = "app${var.application_name}qa-availability-slo-${var.tenant_deployment_id}-${local.random_id}"
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
    google_monitoring_service.qa_cloud_run,
    google_cloud_run_v2_service.qa_app_service,
  ]
}

# Define an uptime check configuration for monitoring service availability.
resource "google_monitoring_uptime_check_config" "qa_https" {
  count = (var.configure_monitoring && var.configure_nonproduction_environment) ? length(local.regions) : 0
  project = local.project.project_id
  display_name = "app${var.application_name}qa-uptime-check-config-${var.tenant_deployment_id}-${local.random_id}"
  timeout = "60s"
  period = "900s"

  http_check {
    path = "/api"
    port = "443"
    use_ssl = true
  }

  monitored_resource {
    type = "cloud_run_revision"
    labels = {
      project_id = local.project.project_id
      service_name = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
      location = local.region
    }
  }

  depends_on = [
    time_sleep.qa_app_service,
    google_cloud_run_v2_service.qa_app_service,
  ]
}

resource "time_sleep" "qa_app_service" {
  create_duration = "60s"
  depends_on = [
    google_cloud_run_v2_service.qa_app_service,
  ]
}

#########################################################################
# Configure Prod resources
#########################################################################

# Define a service for Cloud Run to be monitored.
resource "google_monitoring_service" "prod_cloud_run" {
  count = (var.configure_monitoring && var.configure_production_environment) ? 1 : 0
  service_id   = "app${var.application_name}prod-monitoring-service-${var.tenant_deployment_id}-${local.random_id}-${local.region}"
  display_name = "app${var.application_name}prod-monitoring-service-${var.tenant_deployment_id}-${local.random_id}"
  project      = local.project.project_id

  user_labels = {
    app = "app${var.application_name}${var.tenant_deployment_id}"
    env = "prod"
  }

  basic_service {
    service_type  = "CLOUD_RUN"
    service_labels = {
      location = local.region
      service_name = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
    }
  }

  depends_on = [
    google_cloud_scheduler_job.prod_backup,
    google_cloud_run_v2_service.prod_app_service,
  ]
}

# Define a Service Level Objective (SLO) for Cloud Run service latency.
resource "google_monitoring_slo" "prod_latency_slo" {
  count = (var.configure_monitoring && var.configure_production_environment) ? 1 : 0
  service      = google_monitoring_service.prod_cloud_run[count.index].service_id
  slo_id       = "app${var.application_name}prod-latency-slo-${var.tenant_deployment_id}-${local.random_id}"
  display_name = "app${var.application_name}prod-latency-slo-${var.tenant_deployment_id}-${local.random_id}"
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
    google_monitoring_service.prod_cloud_run,
    google_cloud_run_v2_service.prod_app_service,
  ]
}

# Define a Service Level Objective (SLO) for Cloud Run service availability.
resource "google_monitoring_slo" "prod_availability_slo" {
  count = (var.configure_monitoring && var.configure_production_environment) ? 1 : 0
  service      = google_monitoring_service.prod_cloud_run[count.index].service_id
  slo_id       = "app${var.application_name}prod-availability-slo-${var.tenant_deployment_id}-${local.random_id}"
  display_name = "app${var.application_name}prod-availability-slo-${var.tenant_deployment_id}-${local.random_id}"
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
    google_monitoring_service.prod_cloud_run,
    google_cloud_run_v2_service.prod_app_service,
  ]
}

# Define an uptime check configuration for monitoring service availability.
resource "google_monitoring_uptime_check_config" "prod_https" {
  count = (var.configure_monitoring && var.configure_production_environment) ? length(local.regions) : 0
  project = local.project.project_id
  display_name = "app${var.application_name}prod-uptime-check-config-${var.tenant_deployment_id}-${local.random_id}"
  timeout = "60s"
  period = "900s"

  http_check {
    path = "/api"
    port = "443"
    use_ssl = true
  }

  monitored_resource {
    type = "cloud_run_revision"
    labels = {
      project_id = local.project.project_id
      service_name = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
      location = local.region
    }
  }

  depends_on = [
    time_sleep.prod_app_service,
    google_cloud_run_v2_service.prod_app_service,
  ]
}

resource "time_sleep" "prod_app_service" {
  create_duration = "60s"
  depends_on = [
    google_cloud_run_v2_service.prod_app_service,
  ]
}
