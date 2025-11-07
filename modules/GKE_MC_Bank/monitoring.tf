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
  services = [
    "userservice",
    "contacts",
    "frontend",
    "loadgenerator",
    "payments",
    "currencyservice"
  ]
}

resource "google_monitoring_service" "gke_services" {
  for_each = var.enable_monitoring ? {
    for tuple in setproduct(local.services, keys(local.cluster_configs)) :
    "${tuple[0]}-${tuple[1]}" => {
      service_id  = tuple[0]
      cluster_key = tuple[1]
    }
  } : {}

  project      = local.project.project_id
  service_id   = each.value.service_id
  display_name = each.value.service_id

  basic_service {
    service_type = "gke_service"
    service_labels = {
      project_id     = local.project.project_id
      cluster_name   = local.cluster_configs[each.value.cluster_key].gke_cluster_name
      location       = local.cluster_configs[each.value.cluster_key].region
      namespace_name = "bank-of-anthos"
      service_name   = each.value.service_id
    }
  }

  depends_on = [
    null_resource.deploy_bank_of_anthos,
  ]
}

resource "google_monitoring_slo" "login_slo" {
  for_each = var.enable_monitoring ? toset(keys(local.cluster_configs)) : []

  project      = local.project.project_id
  service      = google_monitoring_service.gke_services["frontend-${each.key}"].service_id
  slo_id       = "login-slo-${each.key}"
  display_name = "Login SLO for ${each.key}"

  goal = 0.9
  calendar_period = "DAY"

  request_based_sli {
    good_total_ratio {
      good_service_filter = "metric.type=\"istio.io/service/server/request_count\" resource.type=\"istio_canonical_service\" resource.label.\"service_namespace\"=\"bank-of-anthos\" resource.label.\"destination_service_name\"=\"frontend\" metric.label.\"response_code\"!=\"500\""
      total_service_filter = "metric.type=\"istio.io/service/server/request_count\" resource.type=\"istio_canonical_service\" resource.label.\"service_namespace\"=\"bank-of-anthos\" resource.label.\"destination_service_name\"=\"frontend\""
    }
  }
}
