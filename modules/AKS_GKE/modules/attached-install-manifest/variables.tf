/**
 * Copyright 2024-2025 Google LLC
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

variable "temp_dir" {
  description = "Local filesystem directory path used to temporarily write out the Helm chart manifests needed to bootstrap the GKE Hub cluster attach process. Defaults to an empty string, which causes the module to use a system-generated temporary directory. The directory is cleaned up automatically after the attach operation completes."
  type        = string
  default     = ""
}

variable "gcp_location" {
  description = "GCP region or zone where the attached cluster resource will be created in GKE Hub (e.g. 'us-central1'). Must match the location used when registering the cluster. Required; no default."
  type        = string
}

variable "platform_version" {
  description = "GKE Hub Attached Clusters platform version for the managed components to install on the external cluster (format: major.minor.patch-gke.N, e.g. '1.34.0-gke.1'). Must be compatible with the Kubernetes version running on the target cluster. Required; no default."
  type        = string
}

variable "attached_cluster_fleet_project" {
  description = "GCP project ID of the fleet project where the external cluster will be attached and managed (format: lowercase letters, digits, and hyphens, e.g. 'my-project-123'). Required; no default."
  type        = string
}

variable "attached_cluster_name" {
  description = "Name for the attached cluster resource as it will appear in GKE Hub (e.g. 'azure-aks-cluster-abc123'). Must be unique within the fleet project and location. Required; no default."
  type        = string
}

variable "helm_timeout" {
  description = "Maximum time in seconds to wait for Helm install/upgrade operations to complete before failing. Defaults to null, which uses Helm's built-in default timeout of 300 seconds. Increase this value if cluster bootstrap operations are slow in the target environment."
  type        = number
  default     = null
}
