/**
 * Copyright 2018-2024 Google LLC
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

variable "kubeconfig" {
  description = "Absolute file path to the kubeconfig file used to authenticate kubectl and asmcli against the target cluster (e.g. '/home/user/.kube/config'). Required; no default. The kubeconfig must contain credentials for the cluster context specified in the context variable."
  type        = string
}

variable "context" {
  description = "Kubernetes context name within the kubeconfig file that identifies the target cluster (e.g. 'aws-eks-cluster-us-west-2'). Required; no default. Run 'kubectl config get-contexts' to list available contexts in your kubeconfig."
  type        = string
}

variable "fleet_id" {
  description = "GCP project ID of the fleet project that hosts the GKE Hub membership for this cluster (format: lowercase letters, digits, and hyphens, e.g. 'my-project-123'). Required; no default. This is the same project ID as attached_cluster_fleet_project in the parent module."
  type        = string
}

variable "platform" {
  description = "Operating system platform on which the asmcli tool will be downloaded and executed. Valid values: 'linux' (default), 'darwin' (macOS). Defaults to 'linux'. Only change this if running Terraform from a macOS environment."
  type        = string
  default     = "linux"
}

variable "service_account_key_file" {
  description = "Absolute path to a GCP service account JSON key file used to authenticate with 'gcloud auth activate-service-account'. Only used when activate_service_account is true and use_tf_google_credentials_env_var is false. Defaults to an empty string (not used). Leave empty if using application default credentials or GOOGLE_CREDENTIALS."
  type        = string
  default     = ""
}

variable "use_tf_google_credentials_env_var" {
  description = "Set to true to authenticate asmcli using the GOOGLE_CREDENTIALS environment variable (a JSON service account key passed as an environment variable). When true, service_account_key_file is ignored. Defaults to false. Useful in CI/CD pipelines where credentials are injected via environment variables."
  type        = bool
  default     = false
}

variable "activate_service_account" {
  description = "Set to true (default) to run 'gcloud auth activate-service-account' before executing asmcli, using either service_account_key_file or GOOGLE_CREDENTIALS. Set to false to skip service account activation when application default credentials or another auth mechanism is already configured."
  type        = bool
  default     = true
}

variable "gcloud_sdk_version" {
  description = "Version of the Google Cloud SDK (gcloud) to download and use for authentication and API calls during mesh installation (e.g. '491.0.0'). Defaults to '491.0.0'. Only change this if a specific gcloud version is required for compatibility. Set gcloud_download_url to override the download location."
  type        = string
  default     = "491.0.0"
}

variable "gcloud_download_url" {
  description = "Custom URL from which to download the gcloud SDK archive. Defaults to null, which uses the official Google Cloud SDK download URL based on gcloud_sdk_version and platform. Set this in air-gapped or restricted environments where access to the official download URL is not available."
  type        = string
  default     = null
}

variable "jq_version" {
  description = "Version of the jq JSON processor to download for use in asmcli helper scripts (e.g. '1.6'). Defaults to '1.6'. Set jq_download_url to override the download location."
  type        = string
  default     = "1.6"
}

variable "jq_download_url" {
  description = "Custom URL from which to download the jq binary. Defaults to null, which uses the official GitHub release URL based on jq_version and platform. Set this in air-gapped or restricted environments."
  type        = string
  default     = null
}

variable "asmcli_version" {
  description = "Version of the asmcli tool to download for installing Anthos Service Mesh (format: major.minor, e.g. '1.22'). Defaults to '1.22'. Must be compatible with the Kubernetes version and ASM version being installed. Set asmcli_download_url to override the download location."
  type        = string
  default     = "1.22"
}

variable "asmcli_download_url" {
  description = "Custom URL from which to download the asmcli binary. Defaults to null, which uses the official Google Cloud Storage URL based on asmcli_version and platform. Set this in air-gapped or restricted environments."
  type        = string
  default     = null
}

variable "asmcli_enable_all" {
  description = "Set to true to pass '--enable_all' to asmcli, which enables all optional features in a single flag (equivalent to enabling cluster_roles, cluster_labels, gcp_components, gcp_apis, gcp_iam_roles, meshconfig_init, namespace_creation, and registration simultaneously). Defaults to false. When true, individual asmcli_enable_* flags are ignored."
  type        = bool
  default     = false
}

variable "asmcli_enable_cluster_roles" {
  description = "Set to true to pass '--enable_cluster_roles' to asmcli, granting the required Kubernetes RBAC cluster roles needed for ASM installation. Defaults to false. Required if the service account lacks pre-existing cluster-admin permissions."
  type        = bool
  default     = false
}

variable "asmcli_enable_cluster_labels" {
  description = "Set to true to pass '--enable_cluster_labels' to asmcli, applying the required mesh-related labels to the cluster resource (e.g. mesh_id label). Defaults to false. Required if cluster labels have not been applied manually prior to installation."
  type        = bool
  default     = false
}

variable "asmcli_enable_gcp_components" {
  description = "Set to true to pass '--enable_gcp_components' to asmcli, enabling required Google-managed GCP components in the cluster (e.g. Workload Identity, GKE metadata server). Defaults to false. Required if these components are not already configured on the cluster."
  type        = bool
  default     = false
}

variable "asmcli_enable_gcp_apis" {
  description = "Set to true to pass '--enable_gcp_apis' to asmcli, automatically enabling the required GCP project APIs (e.g. meshconfig.googleapis.com, mesh.googleapis.com). Defaults to false. Required if APIs have not been enabled manually in the project."
  type        = bool
  default     = false
}

variable "asmcli_enable_gcp_iam_roles" {
  description = "Set to true to pass '--enable_gcp_iam_roles' to asmcli, granting the required GCP IAM roles to the service account used for ASM installation. Defaults to false. Required if the service account lacks the necessary IAM permissions."
  type        = bool
  default     = false
}

variable "asmcli_enable_meshconfig_init" {
  description = "Set to true to pass '--enable_meshconfig_init' to asmcli, initializing the mesh configuration in the GCP project (sets up the meshconfig API endpoint). Defaults to false. Required on first-time ASM installation in a project."
  type        = bool
  default     = false
}

variable "asmcli_enable_namespace_creation" {
  description = "Set to true to pass '--enable_namespace_creation' to asmcli, allowing asmcli to create the 'istio-system' namespace if it does not already exist. Defaults to false. Required if the namespace has not been pre-created."
  type        = bool
  default     = false
}

variable "asmcli_enable_registration" {
  description = "Set to true to pass '--enable_registration' to asmcli, registering the cluster with the GCP fleet (GKE Hub) during ASM installation. Defaults to false. Only needed if the cluster has not already been registered via the attached-install-manifest submodule."
  type        = bool
  default     = false
}

variable "asmcli_ca" {
  description = "Certificate authority type used by the ASM service mesh for issuing workload mTLS certificates. Valid values: 'mesh_ca' (default) = Google-managed Mesh CA, recommended for most deployments; 'gcp_cas' = GCP Certificate Authority Service, for environments requiring custom CA integration; 'citadel' = Istio's built-in Citadel CA, legacy option not recommended for new deployments. Defaults to 'mesh_ca'."
  type        = string
  default     = "mesh_ca"

  validation {
    condition     = contains(["mesh_ca", "gcp_cas", "citadel"], var.asmcli_ca)
    error_message = "The asmcli_ca value must be one of: mesh_ca, gcp_cas, citadel."
  }
}

variable "asmcli_verbose" {
  description = "Set to true to pass '--verbose' to asmcli, enabling detailed debug output during mesh installation. Defaults to false. Useful for troubleshooting installation failures."
  type        = bool
  default     = false
}

variable "asmcli_additional_arguments" {
  description = "Additional command-line arguments to append verbatim to the asmcli command (e.g. '--option1 value1 --option2'). Defaults to null (no additional arguments). Use this to pass asmcli flags not covered by the individual asmcli_* variables above."
  type        = string
  default     = null
}
