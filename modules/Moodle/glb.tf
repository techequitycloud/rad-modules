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
# Configure Dev resources
#########################################################################

# Reserve a global IP address for the load balancer
resource "google_compute_global_address" "default" {
  count   = length(local.regions) >= 2 && var.configure_environment ? 1 : 0
  project = local.project.project_id
  name = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
}

resource "google_compute_backend_service" "default" {
  count                 = length(local.regions) >= 2 && var.configure_environment ? 1 : 0
  project               = local.project.project_id
  provider              = google-beta
  name                  = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  dynamic "backend" {
    for_each = local.regions  # Iterate over each region in local.regions

    content {
      group = google_compute_region_network_endpoint_group.default[backend.key].id
    }
  }

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}

resource "google_compute_url_map" "default" {
  count           = length(local.regions) >= 2 && var.configure_environment ? 1 : 0
  project         = local.project.project_id
  provider        = google-beta
  name            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}-lb-urlmap"
  default_service = google_compute_backend_service.default[count.index].id

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.default[count.index].id
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
  count    = length(local.regions) >= 2 && var.configure_environment ? 1 : 0
  project  = local.project.project_id
  provider = google-beta
  name     = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}-ssl-cert"

  managed {
    domains = ["app${var.application_name}${var.tenant_deployment_id}${local.random_id}.${google_compute_global_address.default[count.index].address}.nip.io"]
  }

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}

resource "google_compute_target_https_proxy" "default" {
  count    = length(local.regions) >= 2 && var.configure_environment ? 1 : 0
  project  = local.project.project_id
  provider = google-beta
  name     = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}-https-proxy"
  url_map  = google_compute_url_map.default[count.index].id
  ssl_certificates = [
    google_compute_managed_ssl_certificate.default[count.index].name
  ]

  depends_on = [
    google_compute_managed_ssl_certificate.default
  ]
}

resource "google_compute_global_forwarding_rule" "default" {
  count                 = length(local.regions) >= 2 && var.configure_environment ? 1 : 0
  project               = local.project.project_id
  provider              = google-beta
  name                  = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}-lb-fr"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_https_proxy.default[count.index].id
  ip_address            = google_compute_global_address.default[count.index].id
  port_range            = "443"

  depends_on            = [
    google_compute_target_https_proxy.default
  ]
}

resource "google_compute_region_network_endpoint_group" "default" {
  count                 = length(local.regions) >= 2 && var.configure_environment ? length(local.regions) : 0
  project               = local.project.project_id
  provider              = google-beta
  name                  = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = local.regions[count.index]
  cloud_run {
    service = google_cloud_run_v2_service.app_service[local.regions[count.index]].name
  }

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}

resource "google_compute_url_map" "https" {
  count    = length(local.regions) >= 2 && var.configure_environment ? 1 : 0
  project  = local.project.project_id
  provider = google-beta
  name     = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}-https-urlmap"

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
  count    = length(local.regions) >= 2 && var.configure_environment ? 1 : 0
  project  = local.project.project_id
  provider = google-beta
  name     = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}-http-proxy"
  url_map  = google_compute_url_map.https[count.index].id

  depends_on = [
    google_compute_url_map.https
  ]
}

resource "google_compute_global_forwarding_rule" "https" {
  count      = length(local.regions) >= 2 && var.configure_environment ? 1 : 0
  project    = local.project.project_id
  provider   = google-beta
  name       = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}-https-fr"
  target     = google_compute_target_http_proxy.https[count.index].id
  ip_address = google_compute_global_address.default[count.index].id
  port_range = "80"

  depends_on = [
    google_compute_target_http_proxy.https
  ]
}
