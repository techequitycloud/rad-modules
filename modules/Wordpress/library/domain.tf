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

resource "google_cloud_run_domain_mapping" "dev_app_domain" {
  count    = (var.application_project == "development" && var.configure_dev_environment && var.configure_mapping) ? 1 : 0
  project  = local.project.project_id
  location = local.region
  name     = "${google_compute_global_address.dev[count.index].address}.nip.io"

  metadata {
    namespace = local.project.project_id
  }

  spec {
    route_name = google_cloud_run_v2_service.dev_app_service[count.index].name
  }

  depends_on = [
    google_cloud_run_v2_service.dev_app_service
  ]
}

resource "google_cloud_run_domain_mapping" "qa_app_domain" {
  count    = (var.application_project == "staging" && var.configure_qa_environment && var.configure_mapping) ? 1 : 0
  project  = local.project.project_id
  location = local.region
  name     = "${google_compute_global_address.qa[count.index].address}.nip.io"

  metadata {
    namespace = local.project.project_id
  }

  spec {
    route_name = google_cloud_run_v2_service.qa_app_service[count.index].name
  }

  depends_on = [
    google_cloud_run_v2_service.qa_app_service
  ]
}

resource "google_cloud_run_domain_mapping" "prod_app_domain" {
  count    = (var.application_project == "production" && var.configure_prod_environment && var.configure_mapping) ? 1 : 0
  project  = local.project.project_id
  location = local.region
  name     = "${google_compute_global_address.prod[count.index].address}.nip.io"

  metadata {
    namespace = local.project.project_id
  }

  spec {
    route_name = google_cloud_run_v2_service.prod_app_service[count.index].name
  }

  depends_on = [
    google_cloud_run_v2_service.prod_app_service
  ]
}

