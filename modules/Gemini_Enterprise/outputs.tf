/**
 * Copyright 2026 Google LLC
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

output "deployment_id" {
  description = "Module Deployment ID"
  value       = local.random_id
}

output "project_id" {
  description = "GCP Project ID"
  value       = local.project.project_id
}

output "demo_bucket" {
  description = "Cloud Storage bucket holding the demo documents, images, BigQuery seed data and ADK agent source"
  value       = google_storage_bucket.demo.name
}

output "drive_documents_console_url" {
  description = "Console page listing the documents to download and upload to Google Drive (lab Task 1)"
  value       = "https://console.cloud.google.com/storage/browser/${google_storage_bucket.demo.name}/drive?project=${local.project.project_id}"
}

output "agent_source_copy_cmd" {
  description = "Cloud Shell command that downloads the ADK agent source, if you want to redeploy or edit it during class"
  value       = "gcloud storage cp -r gs://${google_storage_bucket.demo.name}/adk_to_ge ."
}

output "announcement_image_url" {
  description = "Image URL for the 'Annual pool party' Gemini Enterprise announcement"
  value       = "https://storage.googleapis.com/${google_storage_bucket.demo.name}/pool%20party.png"
}

output "ph_table_image_url" {
  description = "Authenticated console URL of the pH table image used in the 'Convert this image to tabular data' demo"
  value       = "https://storage.cloud.google.com/${google_storage_bucket.demo.name}/pH%20table.png"
}

output "gemini_enterprise_location" {
  description = "Gemini Enterprise location of the app — create the Drive/Calendar connectors and register the agent here too"
  value       = var.ge_location
}

output "gemini_enterprise_app_id" {
  description = "Engine ID of the Gemini Enterprise app, or 'not created' when create_gemini_enterprise_app is false"
  value       = var.create_gemini_enterprise_app ? google_discovery_engine_search_engine.app[0].engine_id : "not created"
}

output "gemini_enterprise_console_url" {
  description = "Gemini Enterprise console page for the project"
  value       = "https://console.cloud.google.com/gemini-enterprise/products?project=${local.project.project_id}"
}

output "cymbal_docs_data_store" {
  description = "Resource name of the data store indexing the Cymbal Pools documents"
  value       = var.create_gemini_enterprise_app ? google_discovery_engine_data_store.cymbal_docs[0].name : "not created"
}

output "bigquery_table" {
  description = "Fully qualified installation_requests table queried by the BigQuery agent"
  value       = "${local.project.project_id}.${google_bigquery_dataset.cymbal_pools.dataset_id}.${google_bigquery_table.installation_requests.table_id}"
}

output "reasoning_engine" {
  description = "Agent Runtime reasoning engine resource name to paste into Gemini Enterprise > Agents > Add agent"
  # Referencing the deploy's id (unknown until apply) is what defers the file
  # read past the deploy. depends_on alone is not enough: every other input is
  # known at plan, so OpenTofu computes the value then and keeps the fallback.
  value = !var.deploy_adk_agent ? "not deployed" : (
    null_resource.deploy_adk_agent[0].id != "" && fileexists(local.engine_file)
    ? trimspace(file(local.engine_file))
    : "Reasoning engine not available - see the Agent Runtime page in region ${var.region}"
  )
}

output "model_armor_template" {
  description = "Model Armor template resource name to enter under Configurations > Assistant > Enable Model Armor"
  value       = var.create_model_armor_template ? google_model_armor_template.demo[0].id : "not created"
}

output "oauth_redirect_uris" {
  description = "Authorized redirect URIs to add to the Web OAuth client used by the Drive/Calendar connectors and the BigQuery agent authorization"
  value = [
    "https://vertexaisearch.cloud.google.com/oauth-redirect",
    "https://vertexaisearch.cloud.google.com/static/oauth/oauth.html",
  ]
}
