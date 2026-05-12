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

locals {
  monitoring_services = [
    "accounts-db",
    "balancereader",
    "contacts",
    "frontend",
    "ledger-db",
    "ledgerwriter",
    "loadgenerator",
    "transactionhistory",
    "userservice",
  ]
}

#########################################################################
# Configure resources
#########################################################################

resource "google_monitoring_service" "gke_services" {
  for_each = var.enable_monitoring ? toset(local.monitoring_services) : []

  service_id   = each.key
  display_name = each.key
  project      = local.project.project_id

  basic_service {
    service_type = "GKE_SERVICE"
    service_labels = {
      cluster_name   = var.gke_cluster
      location       = var.gcp_region
      namespace_name = "bank-of-anthos"
      project_id     = local.project.project_id
      service_name   = each.key
    }
  }
}

resource "google_monitoring_slo" "gke_services_slo_limit_utilization" {
  for_each = var.enable_monitoring ? toset(local.monitoring_services) : []

  project         = local.project.project_id
  service         = google_monitoring_service.gke_services[each.key].service_id
  display_name    = "95.0% - CPU Limit Utilization Metric - Calendar day"
  goal            = 0.95
  calendar_period = "DAY"

  windows_based_sli {
    window_period = "300s"

    metric_sum_in_range {
      time_series = "metric.type=\"kubernetes.io/container/cpu/limit_utilization\" resource.type=\"k8s_container\" AND resource.label.\"namespace_name\"=\"bank-of-anthos\" AND resource.label.\"cluster_name\"=\"${var.gke_cluster}\" AND resource.label.\"container_name\"=\"${each.key}\""
      range {
        min = -9007199254740991
        max = 1
      }
    }
  }
}
