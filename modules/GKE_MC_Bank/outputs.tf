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

output "gke_clusters" {
  description = "The GKE cluster resources."
  value       = { for k, v in google_container_cluster.gke_cluster : k => v }
}

output "gke_cluster_service_account" {
  description = "The service account created for the GKE standard cluster."
  value       = var.create_autopilot_cluster ? null : google_service_account.gke_standard[0]
}
