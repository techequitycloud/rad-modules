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
# Configure Resources
#########################################################################

# Reserve a global IP address for the load balancer
resource "google_compute_global_address" "default" {
  for_each = { for k, v in local.environments : k => v if length(local.regions) >= 2 }
  project = local.project.project_id
  name = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}"
}

resource "google_compute_backend_service" "default" {
  for_each              = { for k, v in local.environments : k => v if length(local.regions) >= 2 }
  provider              = google-beta
  project               = local.project.project_id
  name                  = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  dynamic "backend" {
    for_each = local.regions

    content {
      group = google_compute_region_network_endpoint_group.default["${each.key}-${backend.key}"].id
    }
  }

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}

resource "google_compute_url_map" "default" {
  for_each        = { for k, v in local.environments : k => v if length(local.regions) >= 2 }
  project         = local.project.project_id
  provider        = google-beta
  name            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}-lb-urlmap"
  default_service = google_compute_backend_service.default[each.key].id

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.default[each.key].id
    route_rules {
      priority = 1
      url_redirect {
        https_redirect         = true
        redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
      }
    }
  }

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}

resource "google_compute_managed_ssl_certificate" "default" {
  for_each = { for k, v in local.environments : k => v if length(local.regions) >= 2 }
  project  = local.project.project_id
  provider = google-beta
  name     = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}-ssl-cert"

  managed {
    domains = ["app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}.${google_compute_global_address.default[each.key].address}.nip.io"]
  }

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}

resource "google_compute_target_https_proxy" "default" {
  for_each = { for k, v in local.environments : k => v if length(local.regions) >= 2 }
  project  = local.project.project_id
  provider = google-beta
  name     = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}-https-proxy"
  url_map  = google_compute_url_map.default[each.key].id
  ssl_certificates = [
    google_compute_managed_ssl_certificate.default[each.key].name
  ]

  depends_on = [
    google_compute_managed_ssl_certificate.default
  ]
}

resource "google_compute_global_forwarding_rule" "default" {
  for_each              = { for k, v in local.environments : k => v if length(local.regions) >= 2 }
  project               = local.project.project_id
  provider              = google-beta
  name                  = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}-lb-fr"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_https_proxy.default[each.key].id
  ip_address            = google_compute_global_address.default[each.key].id
  port_range            = "443"

  depends_on            = [
    google_compute_target_https_proxy.default
  ]
}

# Use setproduct to create combinations of environment and region for NEG
resource "google_compute_region_network_endpoint_group" "default" {
  for_each              = { for item in setproduct(keys(local.environments), local.regions) : "${item[0]}-${item[1]}" => { env = item[0], region = item[1], index = index(local.regions, item[1]) } if length(local.regions) >= 2 && local.environments[item[0]] != null }
  # The if condition above is simplified as setproduct already does the combination, but we check if env is enabled (key exists in environments) and regions count.

  project               = local.project.project_id
  provider              = google-beta
  name                  = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.value.env}-neg-${each.value.index}" # Added index to name to avoid collision if region names are same? No, regions are unique. But name must be unique per region. Actually name can be same in different regions? No, resource names must be unique. Wait, NEG is regional resource. Name must be unique within the region. So using just env suffix is fine IF we are deploying only one NEG per region for this app. But wait, we iterate over regions.
  # If we have 2 regions, we create 2 NEGs.
  # Name: ...-dev-neg.
  # If we deploy to us-central1 and us-east1.
  # NEG 1: region=us-central1, name=...-dev-neg.
  # NEG 2: region=us-east1, name=...-dev-neg.
  # This is valid in GCP.
  # However, Terraform requires unique resource keys. The for_each key "${item[0]}-${item[1]}" (e.g. dev-us-central1) handles Terraform uniqueness.
  # The `name` attribute: "app...dev-neg". Is it okay?
  # Yes, creating a NEG with same name in different regions is allowed.

  # However, to be safe and match original which didn't have suffix but was created per region implicitly?
  # Original code:
  # resource "google_compute_region_network_endpoint_group" "dev_default" {
  #   count = ... ? length(local.regions) : 0
  #   name = "...dev-neg"
  #   region = local.regions[count.index]
  # }
  # So yes, name was same.

  network_endpoint_type = "SERVERLESS"
  region                = each.value.region
  cloud_run {
    service = google_cloud_run_v2_service.app_service[each.value.env].name
  }

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}

resource "google_compute_url_map" "https" {
  for_each = { for k, v in local.environments : k => v if length(local.regions) >= 2 }
  project  = local.project.project_id
  provider = google-beta
  name     = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}-https-urlmap"

  default_url_redirect {
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    https_redirect         = true
    strip_query            = false
  }

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}

resource "google_compute_target_http_proxy" "https" {
  for_each = { for k, v in local.environments : k => v if length(local.regions) >= 2 }
  project  = local.project.project_id
  provider = google-beta
  name     = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}-http-proxy"
  url_map  = google_compute_url_map.https[each.key].id

  depends_on = [
    google_compute_url_map.https
  ]
}

resource "google_compute_global_forwarding_rule" "https" {
  for_each   = { for k, v in local.environments : k => v if length(local.regions) >= 2 }
  project    = local.project.project_id
  provider   = google-beta
  name       = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}-https-fr"
  target     = google_compute_target_http_proxy.https[each.key].id
  ip_address = google_compute_global_address.default[each.key].id
  port_range = "80"

  depends_on = [
    google_compute_target_http_proxy.https
  ]
}
