#*
# * Copyright 2024 Google LLC
# *
# * Licensed under the Apache License, Version 2.0 (the "License");
# * you may not use this file except in compliance with the License.
# * You may obtain a copy of the License at
# *
# *      http://www.apache.org/licenses/LICENSE-2.0
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
#

# Network Policy — controls internet egress and external IP allocation for VMware workload VMs.
# Activation can take up to 15 minutes after apply; the edge_services_cidr must
# not overlap with management_cidr or any peered VPC subnets.
#
# GCVE enforces one network policy per VMware Engine network. If a prior failed
# deployment left an orphaned policy in GCP, apply will fail with:
#   "Resource for the given network already exists"
# Recovery: identify and delete the zombie policy manually, then re-apply:
#   gcloud vmware network-policies list \
#     --project=PROJECT_ID --location=REGION \
#     --impersonate-service-account=SA_EMAIL
#   gcloud vmware network-policies delete POLICY_NAME \
#     --project=PROJECT_ID --location=REGION \
#     --impersonate-service-account=SA_EMAIL --quiet
# If no policy appears in the list but the error persists, the policy is stuck
# in GCP internal state — contact GCP support to purge it.

resource "google_vmwareengine_network_policy" "network_policy" {
  project               = local.project.project_id
  location              = var.region
  name                  = local.network_policy_name
  edge_services_cidr    = var.edge_services_cidr
  vmware_engine_network = google_vmwareengine_network.vmware_engine_network.id

  internet_access {
    enabled = var.enable_internet_access
  }

  external_ip {
    enabled = var.enable_external_ip
  }
}
