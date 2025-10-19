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

#########################################################################
# External data source to check for existing GKE cluster
#########################################################################

data "external" "gke_cluster_info" {
  program = ["bash", "${path.module}/scripts/app/get-gkeserver-info.sh", local.project.project_id, var.resource_creator_identity]
}

#########################################################################
# Local variables for GKE infrastructure
#########################################################################

locals {
  gke_cluster_name = try(data.external.gke_cluster_info.result["gke_cluster_name"], "")
  gke_cluster_region = try(data.external.gke_cluster_info.result["gke_cluster_region"], "")
  gke_cluster_exists = try(data.external.gke_cluster_info.result["gke_cluster_exists"], "")

  k8s_credentials_cmd = local.gke_cluster_exists ? "gcloud container clusters get-credentials ${local.gke_cluster_name} --region ${local.gke_cluster_region} --project ${local.project.project_id}" : ""
}

########################################################################################
# Local variables output
########################################################################################

output "gke_cluster_info" {
  value = local.gke_cluster_exists ? {
    cluster_exists      = local.gke_cluster_exists
    cluster_name        = local.gke_cluster_name
    cluster_region      = local.gke_cluster_region
    credentials_command = local.k8s_credentials_cmd
  } : null
}
