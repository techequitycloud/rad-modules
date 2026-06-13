mock_provider "azurerm" {
  features {}
}
mock_provider "google" {}
mock_provider "helm" {}
mock_provider "random" {}

run "defaults_produce_valid_plan" {
  command = plan

  variables {
    project_id      = "test-project-123"
    client_id       = "00000000-0000-0000-0000-000000000001"
    client_secret   = "test-secret"
    tenant_id       = "00000000-0000-0000-0000-000000000002"
    subscription_id = "00000000-0000-0000-0000-000000000003"
    trusted_users   = []
  }

  assert {
    condition     = var.gcp_location == "us-central1"
    error_message = "Default GCP location should be us-central1"
  }

  assert {
    condition     = var.azure_region == "westus2"
    error_message = "Default Azure region should be westus2"
  }

  assert {
    condition     = var.node_count == 3
    error_message = "Default node count should be 3"
  }

  assert {
    condition     = var.cluster_name_prefix == "azure-aks-cluster"
    error_message = "Default cluster name prefix should be azure-aks-cluster"
  }

  assert {
    condition     = var.k8s_version == "1.34"
    error_message = "Default Kubernetes version should be 1.34"
  }

  assert {
    condition     = var.vm_size == "Standard_D2s_v3"
    error_message = "Default VM size should be Standard_D2s_v3"
  }
}

# Validate trusted_users validation — empty strings should be rejected
run "empty_trusted_user_rejected" {
  command = plan

  variables {
    project_id      = "test-project-123"
    client_id       = "00000000-0000-0000-0000-000000000001"
    client_secret   = "test-secret"
    tenant_id       = "00000000-0000-0000-0000-000000000002"
    subscription_id = "00000000-0000-0000-0000-000000000003"
    trusted_users   = [""]
  }

  expect_failures = [var.trusted_users]
}

run "duplicate_trusted_users_rejected" {
  command = plan

  variables {
    project_id      = "test-project-123"
    client_id       = "00000000-0000-0000-0000-000000000001"
    client_secret   = "test-secret"
    tenant_id       = "00000000-0000-0000-0000-000000000002"
    subscription_id = "00000000-0000-0000-0000-000000000003"
    trusted_users   = ["user@example.com", "user@example.com"]
  }

  expect_failures = [var.trusted_users]
}

run "valid_trusted_users_accepted" {
  command = plan

  variables {
    project_id      = "test-project-123"
    client_id       = "00000000-0000-0000-0000-000000000001"
    client_secret   = "test-secret"
    tenant_id       = "00000000-0000-0000-0000-000000000002"
    subscription_id = "00000000-0000-0000-0000-000000000003"
    trusted_users   = ["alice@example.com", "bob@example.com"]
  }

  assert {
    condition     = length(var.trusted_users) == 2
    error_message = "Two distinct trusted users should be accepted"
  }
}
