/**
 * Copyright 2022 Google LLC
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

locals {
  tags = {
    "owner" = tolist(var.trusted_users)[0]
  }

  random_id = var.deployment_id != null ? var.deployment_id : random_id.default.hex

  # Use the existing project data source directly
  project_id     = data.google_project.existing_project.project_id
  project_number = data.google_project.existing_project.number

  # List of default APIs to enable on the Google Cloud project
  default_apis = [
    "gkemulticloud.googleapis.com",
    "gkeconnect.googleapis.com",
    "connectgateway.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "anthos.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "gkehub.googleapis.com",
    "opsconfigmonitoring.googleapis.com",
    "kubernetesmetadata.googleapis.com"
  ]
}

# Generate a random ID if a deployment ID is not provided
resource "random_id" "default" {
  byte_length = 2
}

data "google_project" "existing_project" {
  project_id = trimspace(var.existing_project_id)
}

# Resource to enable APIs on the selected Google Cloud project
resource "google_project_service" "enabled_services" {
  for_each = toset(local.default_apis) # Iterate over each service in the set
  project  = local.project_id         # Apply to the selected project
  service  = each.value               # The API service to enable

  # These settings ensure that disabling or destroying this resource does not affect dependent services
  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.azure_region
  tags     = local.tags
}

resource "azurerm_role_definition" "aks_least_privilege" {
  name        = "CustomRole_AKS_Contributor"
  scope       = azurerm_resource_group.aks.id
  description = "Custom role with least-privilege permissions for AKS"

  permissions {
    actions = [
      "Microsoft.ContainerService/managedClusters/read",
      "Microsoft.ContainerService/managedClusters/write",
      "Microsoft.ContainerService/managedClusters/delete",
      "Microsoft.Network/virtualNetworks/subnets/join/action",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/read"
    ]
    not_actions = []
  }

  assignable_scopes = [
    azurerm_resource_group.aks.id
  ]
}

resource "azurerm_role_assignment" "aks_least_privilege" {
  scope              = azurerm_resource_group.aks.id
  role_definition_id = azurerm_role_definition.aks_least_privilege.id
  principal_id       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name_prefix
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.k8s_version

  # If not enabling the OIDC issuer, extra steps need to be taken to manually retrieve JWKs from the cluster.
  oidc_issuer_enabled = true

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size
    tags       = local.tags
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "google_container_attached_cluster" "primary" {
  name             = var.cluster_name_prefix
  project          = local.project_id
  location         = var.gcp_location
  description      = "AKS attached cluster example"
  distribution     = "aks"
  platform_version = var.platform_version
  oidc_config {
    issuer_url = azurerm_kubernetes_cluster.aks.oidc_issuer_url
    # NOTE: If `oidc_issuer_enabled` is not set to true above, `jwks` needs to be set here.
    # JWKs can be retrieved from the cluster using: `kubectl get --raw /openid/v1/jwks` and
    # must be base64 encoded.
  }
  fleet {
    project = "projects/${local.project_number}"
  }

  logging_config {
    component_config {
      enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
    }
  }

  monitoring_config {
    managed_prometheus_config {
      enabled = true
    }
  }

  authorization {
    admin_users = var.trusted_users
  }

  depends_on = [
    google_project_service.enabled_services,
  ]
}
