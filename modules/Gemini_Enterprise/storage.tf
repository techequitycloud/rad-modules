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

# Demo content bucket. Holds the documents the instructor uploads to Google
# Drive, the announcement image, the BigQuery seed data and the ADK agent
# source — the same content the lab expects to find in "<project>-bucket".
#
# Uniform bucket-level access is deliberately OFF: the announcement image must
# be publicly readable (Gemini Enterprise renders it in every viewer's browser
# straight from its URL) while the rest of the bucket stays private, which
# needs a per-object ACL.
resource "google_storage_bucket" "demo" {
  project                     = local.project.project_id
  name                        = local.bucket_name
  location                    = var.bucket_location
  uniform_bucket_level_access = false
  force_destroy               = true

  depends_on = [google_project_service.enabled_services]
}

resource "google_storage_bucket_object" "drive_documents" {
  for_each = toset(local.drive_documents)
  bucket   = google_storage_bucket.demo.name
  name     = "drive/${each.value}"
  source   = "${path.module}/assets/${each.value}"
}

resource "google_storage_bucket_object" "images" {
  for_each = toset(local.demo_images)
  bucket   = google_storage_bucket.demo.name
  name     = each.value
  source   = "${path.module}/assets/${each.value}"
}

resource "google_storage_bucket_object" "installation_requests_csv" {
  bucket = google_storage_bucket.demo.name
  name   = "bigquery/installation_requests.csv"
  source = "${path.module}/assets/installation_requests.csv"
}

resource "google_storage_bucket_object" "adk_to_ge" {
  for_each = toset(local.adk_files)
  bucket   = google_storage_bucket.demo.name
  name     = "adk_to_ge/${each.value}"
  source   = "${path.module}/adk_to_ge/${each.value}"
}

# Makes only the announcement image public. Fails with a 412 if the project
# enforces constraints/storage.publicAccessPrevention; set
# public_announcement_image = false there and host the image elsewhere.
resource "google_storage_object_acl" "pool_party_public" {
  count          = var.public_announcement_image ? 1 : 0
  bucket         = google_storage_bucket.demo.name
  object         = google_storage_bucket_object.images["pool party.png"].output_name
  predefined_acl = "publicRead"
}
