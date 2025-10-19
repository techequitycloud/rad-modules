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
# Configure resources
#########################################################################

resource "google_iap_brand" "project_brand" {
  count             = var.configure_identity_aware_proxy ? 1 : 0
  support_email     = var.support_email
  application_title = "Cloud IAP Protected Application"
  project           = local.project.project_id

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    time_sleep.wait_120_seconds
  ]
}

resource "google_iap_client" "project_client" {
  count         = var.configure_identity_aware_proxy ? 1 : 0
  display_name  = "IAP Client"
  brand         = google_iap_brand.project_brand[0].name

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    time_sleep.wait_120_seconds,
    google_iap_brand.project_brand
  ]
}
