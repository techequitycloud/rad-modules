mock_provider "google" {}
mock_provider "google-beta" {}
mock_provider "kubernetes" {}

run "defaults_produce_valid_plan" {
  command = plan

  variables {
    project_id = "test-project-123"
  }

  assert {
    condition     = var.cluster_size == 2
    error_message = "Default cluster_size should be 2"
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
    condition     = var.deploy_application == true
    error_message = "deploy_application should default to true"
  }

  assert {
    condition     = length(var.available_regions) >= 1
    error_message = "available_regions must have at least one entry"
  }

  assert {
    condition     = var.release_channel == "REGULAR"
    error_message = "Default release_channel should be REGULAR"
  }
}

run "three_cluster_deployment" {
  command = plan

  variables {
    project_id        = "test-project-123"
    cluster_size      = 3
    available_regions = ["us-central1", "us-east1", "europe-west1"]
  }

  assert {
    condition     = var.cluster_size == 3
    error_message = "cluster_size of 3 should be accepted"
  }
}

run "no_mesh_no_app" {
  command = plan

  variables {
    project_id                = "test-project-123"
    enable_cloud_service_mesh = false
    deploy_application        = false
  }

  assert {
    condition     = var.enable_cloud_service_mesh == false
    error_message = "Should be able to disable service mesh"
  }
}
