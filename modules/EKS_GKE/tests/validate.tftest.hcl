# NOTE: EKS_GKE/provider.tf currently uses get_env() which is a Terragrunt
# function, not valid Terraform. terraform validate will fail until this is
# fixed (replace get_env() calls with coalesce(var.x, "") or remove them).
#
# Fix needed in provider.tf:
#   access_key = var.aws_access_key
#   secret_key = var.aws_secret_key

mock_provider "aws" {}
mock_provider "google" {}
mock_provider "helm" {}

run "defaults_produce_valid_plan" {
  command = plan

  variables {
    project_id    = "test-project-123"
    aws_access_key = "AKIAIOSFODNN7EXAMPLE"
    aws_secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    trusted_users  = []
  }

  assert {
    condition     = var.gcp_location == "us-central1"
    error_message = "Default GCP location should be us-central1"
  }

  assert {
    condition     = var.aws_region == "us-west-2"
    error_message = "Default AWS region should be us-west-2"
  }

  assert {
    condition     = var.cluster_name_prefix == "aws-eks-cluster"
    error_message = "Default cluster name prefix should be aws-eks-cluster"
  }

  assert {
    condition     = var.k8s_version == "1.34"
    error_message = "Default Kubernetes version should be 1.34"
  }

  assert {
    condition     = var.node_group_desired_size == 2
    error_message = "Default desired node count should be 2"
  }

  assert {
    condition     = var.node_group_min_size == 2
    error_message = "Default min node count should be 2"
  }

  assert {
    condition     = var.node_group_max_size == 5
    error_message = "Default max node count should be 5"
  }

  assert {
    condition     = var.enable_public_subnets == true
    error_message = "enable_public_subnets should default to true"
  }

  assert {
    condition     = var.vpc_cidr_block == "10.0.0.0/16"
    error_message = "Default VPC CIDR should be 10.0.0.0/16"
  }
}

run "empty_trusted_user_rejected" {
  command = plan

  variables {
    project_id     = "test-project-123"
    aws_access_key = "AKIAIOSFODNN7EXAMPLE"
    aws_secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    trusted_users  = [""]
  }

  expect_failures = [var.trusted_users]
}

run "duplicate_trusted_users_rejected" {
  command = plan

  variables {
    project_id     = "test-project-123"
    aws_access_key = "AKIAIOSFODNN7EXAMPLE"
    aws_secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    trusted_users  = ["user@example.com", "user@example.com"]
  }

  expect_failures = [var.trusted_users]
}

run "private_subnets_config" {
  command = plan

  variables {
    project_id          = "test-project-123"
    aws_access_key      = "AKIAIOSFODNN7EXAMPLE"
    aws_secret_key      = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    trusted_users       = []
    enable_public_subnets = false
  }

  assert {
    condition     = var.enable_public_subnets == false
    error_message = "Private subnet mode should be accepted"
  }
}
