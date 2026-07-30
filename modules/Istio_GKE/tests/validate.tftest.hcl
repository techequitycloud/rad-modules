mock_provider "google" {}
mock_provider "google-beta" {}
mock_provider "kubernetes" {}

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
    condition     = var.istio_version == "1.24.2"
    error_message = "Default Istio version should be 1.24.2"
  }

  assert {
    condition     = var.install_ambient_mesh == false
    error_message = "Default Istio mode should be sidecar (install_ambient_mesh=false)"
  }

  assert {
    condition     = var.deploy_application == true
    error_message = "deploy_application should default to true"
  }

  assert {
    condition     = var.create_cluster == true
    error_message = "create_cluster should default to true"
  }

  assert {
    condition     = var.release_channel == "REGULAR"
    error_message = "Default release_channel should be REGULAR"
  }
}

run "ambient_mesh_mode" {
  command = plan

  variables {
    project_id           = "test-project-123"
    install_ambient_mesh = true
  }

  assert {
    condition     = var.install_ambient_mesh == true
    error_message = "Ambient mesh mode should be accepted"
  }
}

run "existing_network_config" {
  command = plan

  variables {
    project_id     = "test-project-123"
    create_network = false
    network_name   = "existing-network"
    subnet_name    = "existing-subnet"
  }

  assert {
    condition     = var.create_network == false
    error_message = "Should be able to disable network creation"
  }
}
