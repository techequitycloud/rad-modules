mock_provider "google" {}
mock_provider "random" {}
mock_provider "null" {}
mock_provider "external" {}

run "defaults_produce_valid_plan" {
  command = plan

  variables {
    project_id = "test-project-123"
  }

  assert {
    condition     = var.region == "us-west2"
    error_message = "Default region should be us-west2"
  }

  assert {
    condition     = var.private_cloud_type == "TIME_LIMITED"
    error_message = "Default private_cloud_type should be TIME_LIMITED"
  }

  assert {
    condition     = var.node_count == 1
    error_message = "Default node_count should be 1 for TIME_LIMITED"
  }

  assert {
    condition     = var.node_type_id == "standard-72"
    error_message = "Default node_type_id should be standard-72"
  }

  assert {
    condition     = var.create_vpc == true
    error_message = "create_vpc should default to true"
  }

  assert {
    condition     = var.enable_internet_access == true
    error_message = "enable_internet_access should default to true"
  }

  assert {
    condition     = var.create_jump_host == true
    error_message = "create_jump_host should default to true"
  }
}

# Validate the private_cloud_type validation rule
run "invalid_private_cloud_type_rejected" {
  command = plan

  variables {
    project_id         = "test-project-123"
    private_cloud_type = "INVALID_TYPE"
  }

  expect_failures = [var.private_cloud_type]
}

run "standard_private_cloud_accepted" {
  command = plan

  variables {
    project_id         = "test-project-123"
    private_cloud_type = "STANDARD"
    node_count         = 3
  }

  assert {
    condition     = var.private_cloud_type == "STANDARD"
    error_message = "STANDARD private_cloud_type should be accepted"
  }
}

run "no_jump_host" {
  command = plan

  variables {
    project_id       = "test-project-123"
    create_jump_host = false
  }

  assert {
    condition     = var.create_jump_host == false
    error_message = "Should be able to disable jump host creation"
  }
}
