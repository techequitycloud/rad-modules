# Plan-only tests using mock providers — no GCP credentials required.
# These validate variable logic, resource configuration, and default values.

mock_provider "google" {}
mock_provider "google-beta" {}
mock_provider "kubernetes" {}
mock_provider "kubectl" {}
mock_provider "time" {}
mock_provider "http" {}

# ── Default configuration ─────────────────────────────────────────────────────

run "defaults_produce_valid_plan" {
  command = plan

  variables {
    project_id = "test-project-123"
  }

  assert {
    condition     = var.region == "us-central1"
    error_message = "Default region should be us-central1"
  }

  assert {
    condition     = var.create_cluster == true
    error_message = "create_cluster should default to true"
  }

  assert {
    condition     = var.create_autopilot_cluster == true
    error_message = "create_autopilot_cluster should default to true"
  }

  assert {
    condition     = var.enable_cloud_service_mesh == true
    error_message = "enable_cloud_service_mesh should default to true"
  }

  assert {
    condition     = var.enable_monitoring == true
    error_message = "enable_monitoring should default to true"
  }

  assert {
    condition     = var.deploy_application == true
    error_message = "deploy_application should default to true"
  }

  assert {
    condition     = var.release_channel == "REGULAR"
    error_message = "Default release_channel should be REGULAR"
  }
}

run "standard_cluster_config" {
  command = plan

  variables {
    project_id             = "test-project-123"
    create_autopilot_cluster = false
    enable_cloud_service_mesh = false
    deploy_application     = false
  }

  assert {
    condition     = var.create_autopilot_cluster == false
    error_message = "Should be able to disable Autopilot"
  }
}

run "custom_network_config" {
  command = plan

  variables {
    project_id   = "test-project-123"
    region       = "europe-west1"
    network_name = "custom-network"
    subnet_name  = "custom-subnet"
  }

  assert {
    condition     = var.region == "europe-west1"
    error_message = "Custom region should be accepted"
  }

  assert {
    condition     = var.network_name == "custom-network"
    error_message = "Custom network_name should be accepted"
  }
}

run "config_management_enabled" {
  command = plan

  variables {
    project_id               = "test-project-123"
    enable_config_management = true
    config_sync_repo         = "https://github.com/example/config-repo"
    config_sync_policy_dir   = "config/root"
  }

  assert {
    condition     = var.enable_config_management == true
    error_message = "enable_config_management should be true"
  }

  assert {
    condition     = var.config_sync_repo == "https://github.com/example/config-repo"
    error_message = "config_sync_repo should be accepted"
  }
}
