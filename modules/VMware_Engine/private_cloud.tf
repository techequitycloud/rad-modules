/**
 * Copyright 2024 Google LLC
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

# Private Cloud — provisions vSphere, vSAN, NSX-T, and HCX management appliances.
# management_cidr is immutable after creation; plan this CIDR carefully.
# Provisioning typically takes 30–90 minutes; the 180m timeout reflects this.

# data "external" "private_cloud_exists" {
#   program = [
#     "bash", "-c",
#     "DEPLOY_ID='${coalesce(var.deployment_id, "")}'; if [ -n \"$DEPLOY_ID\" ]; then STATUS=$(gcloud vmware private-clouds describe \"altostrat-$DEPLOY_ID-private-cloud\" --project='${var.project_id}' --location='${var.zone}' --impersonate-service-account='${var.resource_creator_identity}' --format='value(name)' --quiet 2>/dev/null); [ -n \"$STATUS\" ] && echo '{\"exists\":\"true\"}' || echo '{\"exists\":\"false\"}'; else COUNT=$(gcloud vmware private-clouds list --project='${var.project_id}' --location='${var.zone}' --impersonate-service-account='${var.resource_creator_identity}' --format='value(name)' --quiet 2>/dev/null | grep -c . || echo 0); [ \"$COUNT\" -gt 0 ] && echo '{\"exists\":\"true\"}' || echo '{\"exists\":\"false\"}'; fi"
#   ]
# }

resource "google_vmwareengine_private_cloud" "private_cloud" {
  project  = local.project.project_id
  location = var.zone
  name     = local.private_cloud_name
  type     = var.private_cloud_type

  network_config {
    management_cidr       = var.management_cidr
    vmware_engine_network = google_vmwareengine_network.vmware_engine_network.id
  }

  management_cluster {
    cluster_id = "${local.private_cloud_name}-mgmt-cluster"

    node_type_configs {
      node_type_id = var.node_type_id
      node_count   = var.node_count
    }
  }

  timeouts {
    create = "180m"
    update = "180m"
    delete = "180m"
  }

  depends_on = [google_vmwareengine_network.vmware_engine_network]
}
