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

# Pool installation data queried (and written to) by the BigQuery ADK agent in
# the lab's "Demo 3: Custom ADK Agent" section.
resource "google_bigquery_dataset" "cymbal_pools" {
  project                    = local.project.project_id
  dataset_id                 = var.bq_dataset_id
  friendly_name              = "Cymbal Pools"
  description                = "Cymbal Pools Gemini Enterprise demo data (deployment ${local.random_id})."
  location                   = var.bq_location
  delete_contents_on_destroy = true

  depends_on = [google_project_service.enabled_services]
}

resource "google_bigquery_table" "installation_requests" {
  project             = local.project.project_id
  dataset_id          = google_bigquery_dataset.cymbal_pools.dataset_id
  table_id            = "installation_requests"
  description         = "Residential pool installation requests. Dimensions are in metres."
  deletion_protection = false

  schema = jsonencode([
    { name = "request_id", type = "STRING", mode = "REQUIRED", description = "Request identifier, e.g. REQ-1001" },
    { name = "request_date", type = "DATE", mode = "REQUIRED", description = "Date the request was received" },
    { name = "length_m", type = "FLOAT64", mode = "REQUIRED", description = "Pool length in metres" },
    { name = "width_m", type = "FLOAT64", mode = "REQUIRED", description = "Pool width in metres" },
    { name = "depth_m", type = "FLOAT64", mode = "REQUIRED", description = "Pool depth in metres" },
    { name = "has_hot_tub", type = "BOOL", mode = "NULLABLE", description = "Whether a hot tub is included" },
    { name = "has_waterfall", type = "BOOL", mode = "NULLABLE", description = "Whether a waterfall is included" },
    { name = "zip_code", type = "STRING", mode = "NULLABLE", description = "Installation zip code" },
    { name = "customer_phone", type = "STRING", mode = "NULLABLE", description = "Customer phone number" },
    { name = "customer_email", type = "STRING", mode = "NULLABLE", description = "Customer email address" },
  ])
}

# Seeds the table from the CSV in the bucket. The job ID embeds the CSV's hash,
# so the load re-runs (WRITE_TRUNCATE) only when the seed data itself changes —
# a routine re-apply never wipes rows the agent inserted during a demo.
resource "google_bigquery_job" "seed_installation_requests" {
  project  = local.project.project_id
  job_id   = "ge_seed_${local.random_id}_${substr(filemd5("${path.module}/assets/installation_requests.csv"), 0, 12)}"
  location = var.bq_location

  load {
    source_uris = ["gs://${google_storage_bucket.demo.name}/${google_storage_bucket_object.installation_requests_csv.name}"]
    destination_table {
      project_id = local.project.project_id
      dataset_id = google_bigquery_dataset.cymbal_pools.dataset_id
      table_id   = google_bigquery_table.installation_requests.table_id
    }
    source_format         = "CSV"
    skip_leading_rows     = 1
    write_disposition     = "WRITE_TRUNCATE"
    create_disposition    = "CREATE_NEVER"
    autodetect            = false
    allow_quoted_newlines = false
  }

  depends_on = [google_storage_bucket_object.installation_requests_csv]
}
