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

# Define local values for use throughout the Terraform configuration
locals {
  tags = {
    "owner" = tolist(var.trusted_users)[0]
  }

  random_id = var.deployment_id != null ? var.deployment_id : random_id.default[0].hex

  # Use the existing project data source directly
  project_id = data.google_project.existing_project.project_id
  project_number = data.google_project.existing_project.number

  cluster_name_prefix = "${var.cluster_name_prefix}-${random_string.suffix.result}"

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

  cluster_name = "${var.cluster_name_prefix}"
}

# Generate a random ID if a deployment ID is not provided
resource "random_id" "default" {
  count       = var.deployment_id == null ? 1 : 0 
  byte_length = 2 
}

data "google_project" "existing_project" {
  project_id = trimspace(var.existing_project_id)
}

# Resource to enable APIs on the selected Google Cloud project
resource "google_project_service" "enabled_services" {
  for_each                   = toset(local.default_apis) # Iterate over each service in the set
  project                    = local.project_id          # Apply to the selected project
  service                    = each.value                # The API service to enable
  
  # These settings ensure that disabling or destroying this resource does not affect dependent services
  disable_dependent_services = false 
  disable_on_destroy         = false 
}

resource "random_string" "suffix" {
  length    = 2
  special   = false
  lower     = true
  min_lower = 2
}

resource "aws_eks_cluster" "eks" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    subnet_ids = aws_subnet.public[*].id
  }

  version = var.k8s_version

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    time_sleep.wait_120_seconds,
  ]
}

data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.eks.id
}

resource "aws_eks_node_group" "node" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "${var.cluster_name_prefix}-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.public[*].id

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 2
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    time_sleep.wait_120_seconds,
  ]
}

provider "helm" {
  alias = "bootstrap_installer"
  kubernetes {
    host                   = aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

module "attached_install_manifest" {
  source                         = "./modules/attached-install-manifest"
  attached_cluster_name          = "${var.cluster_name_prefix}"
  attached_cluster_fleet_project = local.project_id
  gcp_location                   = var.gcp_location
  platform_version               = var.platform_version
  providers = {
    helm = helm.bootstrap_installer
  }
  # Ensure the node group and route are destroyed after we uninstall the manifest.
  # `terraform destroy` will fail if the module can't access the cluster to clean up.
  depends_on = [
    aws_eks_node_group.node,
    aws_route.public_internet_gateway,
    aws_route_table_association.public,
    time_sleep.wait_120_seconds,
  ]
}

resource "google_container_attached_cluster" "primary" {
  name             = "${var.cluster_name_prefix}"
  project          = local.project_id
  location         = var.gcp_location
  description      = "EKS attached cluster example"
  distribution     = "eks"
  platform_version = var.platform_version
  oidc_config {
    issuer_url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
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
  #   admin_groups = var.groups
  }

  depends_on = [
    module.attached_install_manifest,
    time_sleep.wait_120_seconds,
  ]
}

# Resource to introduce a delay in the Terraform apply operation.
resource "time_sleep" "wait_120_seconds" {
  # Specifies dependencies on organization policies and enabled services, ensuring they are applied before proceeding.
  depends_on = [
    google_project_service.enabled_services
  ]

  create_duration = "120s" # Duration of the delay, set to 120 seconds.
}
