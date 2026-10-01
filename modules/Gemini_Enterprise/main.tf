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

locals {
  random_id      = (var.deployment_id != null && var.deployment_id != "") ? var.deployment_id : random_id.default[0].hex
  project        = try(data.google_project.existing_project, null)
  project_number = try(local.project.number, null)

  default_apis = [
    "discoveryengine.googleapis.com",
    "aiplatform.googleapis.com",
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "modelarmor.googleapis.com",
    "cloudbuild.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
  ]

  project_services = var.enable_services ? local.default_apis : []

  # Resource naming. The bucket is prefixed with the project ID so the public
  # announcement-image URL is self-describing, and suffixed with the
  # deployment ID so it never collides with the "<project>-bucket" bucket
  # Qwiklabs pre-creates in its own lab projects.
  bucket_name        = "${local.project.project_id}-ge-${local.random_id}"
  data_store_id      = "cymbal-pools-docs-${local.random_id}"
  engine_id          = "cymbal-pools-ge-${local.random_id}"
  model_armor_id     = "cymbal-pools-ma-${local.random_id}"
  agent_display_name = "${var.agent_display_name} (${local.random_id})"

  # Discovery Engine (Gemini Enterprise) uses a location-prefixed hostname for
  # every location except "global".
  ge_api_host = var.ge_location == "global" ? "discoveryengine.googleapis.com" : "${var.ge_location}-discoveryengine.googleapis.com"
  # Model Armor templates cannot live in "global" (UNSUPPORTED_REQUEST_LOCATION),
  # so a global app uses the "us" multi-region.
  model_armor_loc     = var.model_armor_location != "" ? var.model_armor_location : (var.ge_location == "global" ? "us" : var.ge_location)
  reasoning_engine_sa = "service-${local.project_number}@gcp-sa-aiplatform-re.iam.gserviceaccount.com"

  # Demo documents are uploaded under drive/ so the instructor can download
  # exactly the files they need to put into Google Drive (Task 1 of the lab).
  drive_documents = [
    "Cymbal Pools Convention Brochure.pdf",
    "Cymbal Pools Pool Installation Analysis.docx",
  ]
  demo_images = [
    "pool party.png",
    "pH table.png",
  ]

  # Every file of the ADK agent package, uploaded to adk_to_ge/ in the bucket so
  # the instructor can still run the lab's own "gcloud storage cp -r" step.
  adk_files = [
    for f in fileset("${path.module}/adk_to_ge", "**") : f
    if !endswith(f, ".pyc") && !strcontains(f, "__pycache__") && !startswith(basename(f), ".")
  ]
}

resource "random_id" "default" {
  count       = (var.deployment_id == null || var.deployment_id == "") ? 1 : 0
  byte_length = 2
}

data "google_project" "existing_project" {
  project_id = trimspace(var.project_id)
}

resource "google_project_service" "enabled_services" {
  for_each                   = toset(local.project_services)
  project                    = local.project.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}
