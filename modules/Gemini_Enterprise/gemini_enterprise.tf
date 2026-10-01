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

# Gemini Enterprise app ("Cymbal Pools GE") — Task 2 of the lab, automated.
#
# What stays manual, and why (see docs/labs/Gemini_Enterprise.md):
#   - Google Drive / Google Calendar connectors: their OAuth handshake only
#     exists in the console's "+ New data store" wizard.
#   - The OAuth consent screen and Web OAuth client (Google Auth Platform UI).
#   - Announcements, Feature Management toggles, and enabling Model Armor on the
#     assistant — these are demoed live in class.
#   - The one-time "Start free trial" activation on a project that has never
#     used Gemini Enterprise. engines.create fails until that has been done.

# Identity provider for the Gemini Enterprise location. Must be set before any
# ACL-enforced connector (Drive/Calendar) can be created there, otherwise the
# console wizard fails with "IdP must be selected before creating an ACLed
# Data Connector".
resource "google_discovery_engine_acl_config" "google_identity" {
  count    = var.configure_google_identity ? 1 : 0
  project  = local.project.project_id
  location = var.ge_location

  idp_config {
    idp_type = "GSUITE"
  }

  depends_on = [google_project_service.enabled_services]
}

# A Cloud Storage-backed data store holding the Cymbal Pools documents. The
# engine API requires at least one data store at creation, and this one also
# means "Search company data" returns grounded answers before the instructor
# has connected Google Drive.
resource "google_discovery_engine_data_store" "cymbal_docs" {
  count                       = var.create_gemini_enterprise_app ? 1 : 0
  project                     = local.project.project_id
  location                    = var.ge_location
  data_store_id               = local.data_store_id
  display_name                = "Cymbal Pools Documents"
  industry_vertical           = "GENERIC"
  content_config              = "CONTENT_REQUIRED"
  solution_types              = ["SOLUTION_TYPE_SEARCH"]
  create_advanced_site_search = false

  lifecycle {
    # The API fills in a default document_processing_config on create; without
    # this every later plan forces a replacement, wiping the indexed documents.
    ignore_changes = [document_processing_config]
  }

  depends_on = [google_discovery_engine_acl_config.google_identity]
}

# Discovery Engine reads the bucket with its own service agent, which only
# exists once it has been explicitly provisioned.
resource "google_project_service_identity" "discoveryengine" {
  count    = var.create_gemini_enterprise_app ? 1 : 0
  provider = google-beta
  project  = local.project.project_id
  service  = "discoveryengine.googleapis.com"

  depends_on = [google_project_service.enabled_services]
}

resource "google_storage_bucket_iam_member" "discoveryengine_reader" {
  count  = var.create_gemini_enterprise_app ? 1 : 0
  bucket = google_storage_bucket.demo.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:service-${local.project_number}@gcp-sa-discoveryengine.iam.gserviceaccount.com"

  depends_on = [google_project_service_identity.discoveryengine]
}

# documents:import has no Terraform resource. The import is asynchronous;
# indexing finishes a few minutes after apply returns.
resource "null_resource" "import_cymbal_docs" {
  count = var.create_gemini_enterprise_app ? 1 : 0

  triggers = {
    data_store = google_discovery_engine_data_store.cymbal_docs[0].name
    documents  = join(",", [for o in google_storage_bucket_object.drive_documents : o.md5hash])
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      API_HOST    = local.ge_api_host
      DATA_STORE  = google_discovery_engine_data_store.cymbal_docs[0].name
      PROJECT_ID  = local.project.project_id
      INPUT_URI   = "gs://${google_storage_bucket.demo.name}/drive/*"
      IMPERSONATE = var.resource_creator_identity
    }
    command = <<-EOT
      set -eo pipefail
      IMP_FLAG=""
      [ -n "$IMPERSONATE" ] && IMP_FLAG="--impersonate-service-account=$IMPERSONATE"
      TOKEN=$(gcloud auth print-access-token $IMP_FLAG)
      echo "Importing Cymbal Pools documents from $INPUT_URI into $DATA_STORE"
      # The Discovery Engine service agent's bucket grant can take a minute to
      # propagate; retry the import request itself a few times.
      for i in 1 2 3 4 5 6; do
        HTTP=$(curl -sS -o /tmp/ge_import_$$.json -w '%%{http_code}' -X POST \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -H "X-Goog-User-Project: $PROJECT_ID" \
          "https://$API_HOST/v1/$DATA_STORE/branches/default_branch/documents:import" \
          -d "{\"gcsSource\":{\"inputUris\":[\"$INPUT_URI\"],\"dataSchema\":\"content\"},\"reconciliationMode\":\"INCREMENTAL\"}")
        if [ "$HTTP" = "200" ]; then
          echo "Import started: $(grep -o '"name": *"[^"]*"' /tmp/ge_import_$$.json | head -1)"
          rm -f /tmp/ge_import_$$.json
          exit 0
        fi
        echo "Attempt $i: HTTP $HTTP -- $(head -c 400 /tmp/ge_import_$$.json)"
        sleep 20
      done
      rm -f /tmp/ge_import_$$.json
      echo "ERROR: documents:import did not start after 6 attempts" >&2
      exit 1
    EOT
  }

  depends_on = [google_storage_bucket_iam_member.discoveryengine_reader]
}

resource "google_discovery_engine_search_engine" "app" {
  count             = var.create_gemini_enterprise_app ? 1 : 0
  project           = local.project.project_id
  location          = var.ge_location
  collection_id     = "default_collection"
  engine_id         = local.engine_id
  display_name      = var.app_display_name
  industry_vertical = "GENERIC"
  app_type          = "APP_TYPE_INTRANET"
  data_store_ids    = [google_discovery_engine_data_store.cymbal_docs[0].data_store_id]

  search_engine_config {
    search_tier    = "SEARCH_TIER_ENTERPRISE"
    search_add_ons = ["SEARCH_ADD_ON_LLM"]
  }

  common_config {
    company_name = var.company_name
  }

  lifecycle {
    # The instructor attaches the Drive/Calendar/Announcements data stores and
    # flips Feature Management toggles (Agent Designer, image model, session
    # sharing) in the console as part of the demo. Without this, the next
    # apply would silently detach those connectors and revert the toggles.
    ignore_changes = [data_store_ids, features, knowledge_graph_config]
  }

  depends_on = [google_discovery_engine_acl_config.google_identity]
}
