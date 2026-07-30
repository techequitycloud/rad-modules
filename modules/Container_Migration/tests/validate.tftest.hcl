mock_provider "google" {}
mock_provider "random" {}
mock_provider "null" {}

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
    condition     = var.gke_node_count == 3
    error_message = "Default GKE node count should be 3"
  }

  assert {
    condition     = var.m2c_disk_size_gb == 200
    error_message = "m2c disk must default to 200 GB to hold source VM filesystems"
  }

  assert {
    condition     = var.create_vpc == true
    error_message = "create_vpc should default to true"
  }

  assert {
    condition     = var.create_default_firewall_rules == true
    error_message = "create_default_firewall_rules should default to true"
  }

  assert {
    condition     = var.postgres_machine_type == "e2-medium"
    error_message = "Default postgres machine type should be e2-medium"
  }

  assert {
    condition     = var.tomcat_machine_type == "e2-medium"
    error_message = "Default tomcat machine type should be e2-medium"
  }
}

run "custom_region_and_zone" {
  command = plan

  variables {
    project_id = "test-project-123"
    region     = "europe-west1"
    zone       = "europe-west1-b"
  }

  assert {
    condition     = var.region == "europe-west1"
    error_message = "Custom region should be accepted"
  }

  assert {
    condition     = var.zone == "europe-west1-b"
    error_message = "Custom zone should be accepted"
  }
}

run "larger_m2c_disk" {
  command = plan

  variables {
    project_id       = "test-project-123"
    m2c_disk_size_gb = 500
  }

  assert {
    condition     = var.m2c_disk_size_gb == 500
    error_message = "Custom m2c disk size should be accepted"
  }
}
