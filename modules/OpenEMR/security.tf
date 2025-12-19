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

# Cloud Armor configuration
resource "google_compute_security_policy" "security_policy" {
  count = (var.configure_environment && var.configure_application_security && length(var.application_authorized_network) > 0 && length(var.application_secure_path) > 0) ? 1 : 0
  name    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  project = local.project.project_id

  # Rule to allow access from authorized IP ranges
  rule {
    action   = "allow"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.application_authorized_network
      }
    }
    description = "Allow access from authorized IP ranges"
  }

  # Rule to deny access to specific URL paths
  rule {
    action   = "deny(403)"
    priority = 1100
    match {
      expr {
        expression = "request.path.matches(\"${var.application_secure_path}\")"
      }
    }
    description = "Deny access to specific URL paths"
  }

  # Default rule to deny all other traffic
  rule {
    action   = "deny(403)"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Deny access to all other IPs"
  }
}
