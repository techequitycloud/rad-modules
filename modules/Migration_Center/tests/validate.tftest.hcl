mock_provider "google" {}
mock_provider "aws" {}

# OpenTofu fills computed attributes with random mixed-case strings at
# PLAN time, so an unconfigured mock gives random_id.hex a value like
# "XI5VmJx9YoV" -- one the real resource can never produce (it is lowercase hex)
# and which the google provider then rejects in every resource name built from
# it. Pin it to a realistic value. Terraform leaves it unknown at plan, so this
# is a no-op there.
mock_provider "random" {
  mock_resource "random_id" {
    defaults = {
      hex = "a1b2"
    }
  }
}

mock_provider "null" {}
mock_provider "tls" {}

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
    condition     = var.zone == "us-central1-a"
    error_message = "Default zone should be us-central1-a"
  }

  assert {
    condition     = var.linux_vm_count == 3
    error_message = "Default linux_vm_count should be 3"
  }

  assert {
    condition     = var.create_windows_vm == true
    error_message = "create_windows_vm should default to true"
  }

  assert {
    condition     = var.windows_vm_boot_disk_size_gb == 50
    error_message = "Windows VM disk should default to 50 GB"
  }

  assert {
    condition     = var.initialize_migration_center == true
    error_message = "initialize_migration_center should default to true"
  }

  assert {
    condition     = var.create_ssh_key_bucket == true
    error_message = "create_ssh_key_bucket should default to true"
  }

  assert {
    condition     = var.mc_discovery_client_name == "mc-discovery-client"
    error_message = "Default discovery client name should be mc-discovery-client"
  }
}

run "aws_integration_skipped_when_no_credentials" {
  command = plan

  variables {
    project_id            = "test-project-123"
    aws_access_key_id     = ""
    aws_secret_access_key = ""
  }

  assert {
    condition     = var.aws_access_key_id == ""
    error_message = "Empty aws_access_key_id should be accepted to skip AWS integration"
  }
}

run "minimal_linux_vms" {
  command = plan

  variables {
    project_id     = "test-project-123"
    linux_vm_count = 1
  }

  assert {
    condition     = var.linux_vm_count == 1
    error_message = "Single Linux VM count should be accepted"
  }
}
