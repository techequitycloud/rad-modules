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
resource "google_compute_global_address" "dev" {
  project = local.project.project_id
  name = "app${var.application_name}${var.customer_identifier}${local.random_id}dev"
}

resource "google_compute_region_network_endpoint_group" "dev_app_neg" {
  count                 = var.configure_glb ? 1 : 0
  name                  = "app${var.application_name}${var.customer_identifier}${local.random_id}dev"
  network_endpoint_type = "SERVERLESS"
  region                = google_cloud_run_v2_service.dev_app_service[count.index].location
  cloud_run {
    service = google_cloud_run_v2_service.dev_app_service[count.index].name
  }

  depends_on = [
    google_cloud_run_v2_service.dev_app_service
  ]
}

module "dev_app_lb" {
  count             = var.configure_glb ? 1 : 0
  source            = "GoogleCloudPlatform/lb-http/google//modules/serverless_negs"
  version           = "~> 12.1.4"

  project = local.project.project_id
  name    = "app${var.application_name}${var.customer_identifier}${local.random_id}dev"

  ssl                             = true
  managed_ssl_certificate_domains = ["app${var.application_name}${var.customer_identifier}${local.random_id}dev.${google_compute_global_address.dev.address}.nip.io"]
  https_redirect                  = true
  backends = {
    default = {
      description            = null
      protocol               = "HTTP"
      enable_cdn             = false
      custom_request_headers          = null
      custom_response_headers         = null

      log_config = {
        enable      = true
        sample_rate = 1.0
      }

      groups = [
        {
          group = google_compute_region_network_endpoint_group.dev_app_neg[count.index].id
        }
      ]

      iap_config = {
        enable               = false
        oauth2_client_id     = null
        oauth2_client_secret = null
      }
      security_policy = null
    }
  }

  depends_on = [
    google_compute_region_network_endpoint_group.dev_app_neg
  ]
}

#########################################################################
# Configure QA resources
#########################################################################

# Reserve a global IP address for the load balancer
resource "google_compute_global_address" "qa" {
  project = local.project.project_id
  name = "app${var.application_name}${var.customer_identifier}${local.random_id}qa"
}

resource "google_compute_region_network_endpoint_group" "qa_app_neg" {
  count                 = var.configure_glb ? 1 : 0
  name                  = "app${var.application_name}${var.customer_identifier}${local.random_id}qa"
  network_endpoint_type = "SERVERLESS"
  region                = google_cloud_run_v2_service.qa_app_service[count.index].location
  cloud_run {
    service = google_cloud_run_v2_service.qa_app_service[count.index].name
  }

  depends_on = [
    google_cloud_run_v2_service.qa_app_service
  ]
}

module "qa_app_lb" {
  count             = var.configure_glb ? 1 : 0
  source            = "GoogleCloudPlatform/lb-http/google//modules/serverless_negs"
  version           = "~> 12.1.4"

  project = local.project.project_id
  name    = "app${var.application_name}${var.customer_identifier}${local.random_id}qa"

  ssl                             = true
  managed_ssl_certificate_domains = ["app${var.application_name}${var.customer_identifier}${local.random_id}qa.${google_compute_global_address.qa.address}.nip.io"]
  https_redirect                  = true
  backends = {
    default = {
      description            = null
      protocol               = "HTTP"
      enable_cdn             = false
      custom_request_headers          = null
      custom_response_headers         = null

      log_config = {
        enable      = true
        sample_rate = 1.0
      }

      groups = [
        {
          group = google_compute_region_network_endpoint_group.qa_app_neg[count.index].id
        }
      ]

      iap_config = {
        enable               = false
        oauth2_client_id     = null
        oauth2_client_secret = null
      }
      security_policy = null
    }
  }

  depends_on = [
    google_compute_region_network_endpoint_group.qa_app_neg
  ]
}

#########################################################################
# Configure Prod resources
#########################################################################

# Reserve a global IP address for the load balancer
resource "google_compute_global_address" "prod" {
  project = local.project.project_id
  name = "app${var.application_name}${var.customer_identifier}${local.random_id}prod"
}

resource "google_compute_region_network_endpoint_group" "prod_app_neg" {
  count                 = var.configure_glb ? 1 : 0
  name                  = "app${var.application_name}${var.customer_identifier}${local.random_id}prod"
  network_endpoint_type = "SERVERLESS"
  region                = google_cloud_run_v2_service.prod_app_service[count.index].location
  cloud_run {
    service = google_cloud_run_v2_service.prod_app_service[count.index].name
  }

  depends_on = [
    google_cloud_run_v2_service.prod_app_service
  ]
}

module "prod_app_lb" {
  count             = var.configure_glb ? 1 : 0
  source            = "GoogleCloudPlatform/lb-http/google//modules/serverless_negs"
  version           = "~> 12.1.4"

  project = local.project.project_id
  name    = "app${var.application_name}${var.customer_identifier}${local.random_id}prod"

  ssl                             = true
  managed_ssl_certificate_domains = ["app${var.application_name}${var.customer_identifier}${local.random_id}prod.${google_compute_global_address.prod.address}.nip.io"]
  https_redirect                  = true
  backends = {
    default = {
      description            = null
      protocol               = "HTTP"
      enable_cdn             = false
      custom_request_headers          = null
      custom_response_headers         = null

      log_config = {
        enable      = true
        sample_rate = 1.0
      }

      groups = [
        {
          group = google_compute_region_network_endpoint_group.prod_app_neg[count.index].id
        }
      ]

      iap_config = {
        enable               = false
        oauth2_client_id     = null
        oauth2_client_secret = null
      }
      security_policy = null
    }
  }

  depends_on = [
    google_compute_region_network_endpoint_group.prod_app_neg
  ]
}

