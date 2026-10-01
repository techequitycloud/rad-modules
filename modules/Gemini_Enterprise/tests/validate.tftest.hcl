mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      number = "123456789012"
    }
  }
}
mock_provider "google-beta" {}
mock_provider "random" {}
mock_provider "null" {}

run "defaults_produce_valid_plan" {
  command = plan

  variables {
    project_id = "test-project-123"
  }

  assert {
    condition     = var.ge_location == "global"
    error_message = "Default Gemini Enterprise location should be global"
  }

  assert {
    condition     = length(google_discovery_engine_search_engine.app) == 1
    error_message = "The Gemini Enterprise app should be created by default"
  }

  assert {
    condition     = google_discovery_engine_search_engine.app[0].app_type == "APP_TYPE_INTRANET"
    error_message = "Gemini Enterprise apps must be APP_TYPE_INTRANET"
  }

  assert {
    condition     = google_discovery_engine_search_engine.app[0].common_config[0].company_name == "Cymbal Pools"
    error_message = "Company name should default to Cymbal Pools"
  }

  assert {
    condition     = length(google_storage_bucket_object.drive_documents) == 2
    error_message = "Both Drive demo documents should be uploaded"
  }

  assert {
    condition     = contains(keys(google_storage_bucket_object.adk_to_ge), "bigquery_agent/agent.py")
    error_message = "The ADK agent source should be uploaded to the bucket"
  }

  assert {
    condition     = length(google_storage_object_acl.pool_party_public) == 1
    error_message = "The announcement image should be public by default"
  }

  assert {
    condition     = length(null_resource.deploy_adk_agent) == 1 && length(google_project_iam_member.reasoning_engine_roles) == 3
    error_message = "The ADK agent and its three service-agent roles should be created by default"
  }

  assert {
    condition     = google_model_armor_template.demo[0].location == "us"
    error_message = "A global app's Model Armor template should default to the us multi-region"
  }

  assert {
    condition     = alltrue([for s in google_project_service.enabled_services : s.disable_on_destroy == false && s.disable_dependent_services == false])
    error_message = "APIs must never be disabled on destroy"
  }
}

run "minimal_supporting_infra_only" {
  command = plan

  variables {
    project_id                   = "test-project-123"
    create_gemini_enterprise_app = false
    deploy_adk_agent             = false
    create_model_armor_template  = false
    public_announcement_image    = false
  }

  assert {
    condition     = length(google_discovery_engine_search_engine.app) == 0 && length(google_discovery_engine_data_store.cymbal_docs) == 0
    error_message = "No app or data store should be planned when create_gemini_enterprise_app is false"
  }

  assert {
    condition     = length(null_resource.deploy_adk_agent) == 0 && length(google_project_iam_member.reasoning_engine_roles) == 0
    error_message = "No agent deploy or service-agent IAM when deploy_adk_agent is false"
  }

  assert {
    condition     = length(google_model_armor_template.demo) == 0 && length(google_storage_object_acl.pool_party_public) == 0
    error_message = "Model Armor template and public ACL should be skipped"
  }
}

run "regional_location_and_model_armor_override" {
  command = plan

  variables {
    project_id           = "test-project-123"
    ge_location          = "us"
    model_armor_location = "us-central1"
  }

  assert {
    condition     = google_discovery_engine_search_engine.app[0].location == "us"
    error_message = "App should follow ge_location"
  }

  assert {
    condition     = google_model_armor_template.demo[0].location == "us-central1"
    error_message = "model_armor_location should override ge_location"
  }
}

run "rejects_invalid_ge_location" {
  command = plan

  variables {
    project_id  = "test-project-123"
    ge_location = "us-central1"
  }

  expect_failures = [var.ge_location]
}
