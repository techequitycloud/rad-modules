/**
 * Copyright 2024 Google LLC
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

# ─── Step 1: Initialize Migration Center ────────────────────────────────────
# Initialises the Migration Center service for the project and region.
# This is a one-time, idempotent operation; re-running against an already-
# initialised project is a no-op. The REST call mirrors the console step where
# the user selects a geographic region and clicks "Next".
resource "null_resource" "mc_init" {
  count = var.initialize_migration_center ? 1 : 0

  triggers = {
    project = local.project.project_id
    region  = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Initializing Migration Center in ${var.region}..."
      TOKEN=$(gcloud auth print-access-token \
        --impersonate-service-account='${var.resource_creator_identity}' \
        --quiet 2>/dev/null)

      MAX_ATTEMPTS=6
      ATTEMPT=0
      WAIT=10
      STATUS=""

      while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        ATTEMPT=$((ATTEMPT + 1))
        echo "Attempt $ATTEMPT/$MAX_ATTEMPTS..."
        STATUS=$(curl -s -o /dev/null -w "%%{http_code}" \
          -X POST \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{}' \
          "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}:initializeConfig")

        if [ "$STATUS" = "200" ] || [ "$STATUS" = "409" ]; then
          echo "Migration Center initialized (HTTP $STATUS)."
          exit 0
        fi

        echo "initializeConfig returned HTTP $STATUS — waiting $${WAIT}s before retry..."
        sleep $WAIT
        WAIT=$((WAIT * 2))
        TOKEN=$(gcloud auth print-access-token \
          --impersonate-service-account='${var.resource_creator_identity}' \
          --quiet 2>/dev/null)
      done

      echo "ERROR: initializeConfig failed after $MAX_ATTEMPTS attempts (last HTTP $STATUS)."
      echo "Check that migrationcenter.googleapis.com is enabled and the SA has the Owner role."
      exit 1
    EOT
  }

  depends_on = [google_project_service.enabled_services]
}

# ─── Step 2: Create a Discovery Source ───────────────────────────────────────
# Registers an MC Discovery Client source. The source ID produced here is what
# users select in the MCDCv6 "Choose a Project" screen. The source name must
# match var.mc_discovery_client_name when the user completes the MCDCv6 login.
resource "null_resource" "mc_source" {
  count = var.initialize_migration_center ? 1 : 0

  triggers = {
    source_name = local.mc_source_name
    project     = local.project.project_id
    region      = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating Migration Center discovery source '${local.mc_source_name}'..."
      TOKEN=$(gcloud auth print-access-token \
        --impersonate-service-account='${var.resource_creator_identity}' \
        --quiet 2>/dev/null)

      RESPONSE=$(curl -s -w "\n%%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
          "displayName": "${var.mc_discovery_client_name}",
          "type": "GUEST_OS_SCAN",
          "managedObjectType": "VIRTUAL_MACHINE"
        }' \
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/sources?sourceId=${local.mc_source_name}")

      HTTP_CODE=$(echo "$RESPONSE" | tail -1)
      if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "409" ]; then
        echo "Discovery source created or already exists (HTTP $HTTP_CODE)."
      else
        echo "ERROR: Source creation returned HTTP $HTTP_CODE."
        echo "$RESPONSE" | head -1
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.mc_init]
}

# ─── Step 3: Import AWS Sample Data ──────────────────────────────────────────
# Downloads the four AWS CSV export files from the public lab bucket and imports
# them into Migration Center. This populates the asset inventory with simulated
# AWS VM data that users can explore alongside their live scan results.
resource "null_resource" "mc_aws_import" {
  count = (var.initialize_migration_center && var.import_aws_sample_data) ? 1 : 0

  triggers = {
    import_name = local.aws_import_name
    project     = local.project.project_id
    region      = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Downloading AWS sample import files..."
      TMPDIR=$(mktemp -d)
      curl -sL "https://storage.googleapis.com/spls/gsp1095/vm-aws-import-files.zip" \
        -o "$TMPDIR/aws-import.zip"
      unzip -q "$TMPDIR/aws-import.zip" -d "$TMPDIR/aws-files"

      TOKEN=$(gcloud auth print-access-token \
        --impersonate-service-account='${var.resource_creator_identity}' \
        --quiet 2>/dev/null)

      echo "Creating AWS import job '${local.aws_import_name}'..."
      CREATE_RESP=$(curl -s -w "\n%%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
          "displayName": "aws-account-import",
          "assetSource": "projects/${local.project.project_id}/locations/${var.region}/sources/${local.mc_source_name}"
        }' \
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/importJobs?importJobId=${local.aws_import_name}")

      HTTP_CODE=$(echo "$CREATE_RESP" | tail -1)
      if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "409" ]; then
        echo "WARNING: Import job creation returned HTTP $HTTP_CODE — skipping file upload."
        echo "$CREATE_RESP" | head -1
        exit 0
      fi

      echo "Uploading CSV files..."
      for CSV_FILE in "$TMPDIR/aws-files"/*.csv; do
        FILENAME=$(basename "$CSV_FILE")
        echo "  Uploading $FILENAME..."
        curl -s -o /dev/null \
          -X POST \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: text/csv" \
          --data-binary "@$CSV_FILE" \
          "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/importJobs/${local.aws_import_name}/importDataFiles?importDataFileId=$(echo "$FILENAME" | tr '.' '-' | tr ' ' '-')" \
          || echo "  WARNING: Upload of $FILENAME returned an error — continuing."
      done

      echo "Validating import job..."
      curl -s -o /dev/null \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{}' \
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/importJobs/${local.aws_import_name}:validate" \
        || echo "WARNING: Validate call returned an error — run manually if needed."

      echo "Running import job..."
      curl -s -o /dev/null \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{}' \
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/importJobs/${local.aws_import_name}:run" \
        || echo "WARNING: Run call returned an error — the job may still be processing."

      echo "AWS data import job submitted. Check Migration Center console for status."
      rm -rf "$TMPDIR"
    EOT
  }

  depends_on = [null_resource.mc_source]
}

# ─── Step 4: Create Asset Groups ─────────────────────────────────────────────
# Creates three asset groups matching the lab: All Assets, windows-only,
# linux-only. Group membership is set after the import completes via criteria.
resource "null_resource" "mc_groups" {
  count = (var.initialize_migration_center && var.generate_reports) ? 1 : 0

  triggers = {
    group_all = local.group_all_name
    project   = local.project.project_id
    region    = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      TOKEN=$(gcloud auth print-access-token \
        --impersonate-service-account='${var.resource_creator_identity}' \
        --quiet 2>/dev/null)

      create_group() {
        local GROUP_ID="$1"
        local DISPLAY_NAME="$2"
        echo "Creating group '$DISPLAY_NAME'..."
        curl -s -o /dev/null \
          -X POST \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d "{\"displayName\": \"$DISPLAY_NAME\"}" \
          "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/groups?groupId=$GROUP_ID" \
          || echo "WARNING: Group '$DISPLAY_NAME' creation failed (may already exist)."
      }

      create_group "${local.group_all_name}" "All Assets"
      create_group "${local.group_win_name}" "windows-only"
      create_group "${local.group_lin_name}" "linux-only"

      echo "Asset groups created."
    EOT
  }

  depends_on = [null_resource.mc_source, null_resource.mc_aws_import]
}

# ─── Step 5: Create Migration Preferences ────────────────────────────────────
# Creates the two preference sets used in the lab TCO report:
#   aggressive-3yr  — N2/N2D, aggressive sizing, 3-year CUD
#   moderate-1yr    — C2/C2D, SSD, moderate sizing, 1-year CUD
resource "null_resource" "mc_preferences" {
  count = (var.initialize_migration_center && var.generate_reports) ? 1 : 0

  triggers = {
    pref_agg = local.pref_agg_name
    pref_mod = local.pref_mod_name
    project  = local.project.project_id
    region   = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      TOKEN=$(gcloud auth print-access-token \
        --impersonate-service-account='${var.resource_creator_identity}' \
        --quiet 2>/dev/null)

      echo "Creating aggressive-3yr migration preferences..."
      curl -s -o /dev/null \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
          "displayName": "aggressive-optimization-3-year-commit",
          "virtualMachinePreferences": {
            "targetProduct": "COMPUTE_MIGRATION_TARGET_PRODUCT_COMPUTE_ENGINE",
            "computeEnginePreferences": {
              "machinePreferences": {
                "allowedMachineSeries": [
                  {"code": "n2"},
                  {"code": "n2d"}
                ]
              },
              "licenseType": "LICENSE_TYPE_DEFAULT"
            },
            "sizingOptimizationStrategy": "SIZING_OPTIMIZATION_STRATEGY_AGGRESSIVE",
            "commitmentPlan": "COMMITMENT_PLAN_THREE_YEAR"
          }
        }' \
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/preferenceSets?preferenceSetId=${local.pref_agg_name}" \
        || echo "WARNING: Aggressive preference creation failed (may already exist)."

      echo "Creating moderate-1yr migration preferences..."
      curl -s -o /dev/null \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
          "displayName": "moderate-optimization-1-year-commit",
          "virtualMachinePreferences": {
            "targetProduct": "COMPUTE_MIGRATION_TARGET_PRODUCT_COMPUTE_ENGINE",
            "computeEnginePreferences": {
              "machinePreferences": {
                "allowedMachineSeries": [
                  {"code": "c2"},
                  {"code": "c2d"}
                ]
              },
              "licenseType": "LICENSE_TYPE_DEFAULT",
              "persistentDiskType": "PERSISTENT_DISK_TYPE_SSD"
            },
            "sizingOptimizationStrategy": "SIZING_OPTIMIZATION_STRATEGY_MODERATE",
            "commitmentPlan": "COMMITMENT_PLAN_ONE_YEAR"
          }
        }' \
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/preferenceSets?preferenceSetId=${local.pref_mod_name}" \
        || echo "WARNING: Moderate preference creation failed (may already exist)."

      echo "Migration preferences created."
    EOT
  }

  depends_on = [null_resource.mc_groups]
}

# ─── Step 6: Create Report Config and Generate TCO Report ────────────────────
# Creates a report configuration referencing all three groups and both preference
# sets, then triggers generation. Report takes up to 5 minutes; users can
# monitor progress in the Migration Center console.
resource "null_resource" "mc_report" {
  count = (var.initialize_migration_center && var.generate_reports) ? 1 : 0

  triggers = {
    report_name = var.mc_report_name
    project     = local.project.project_id
    region      = var.region
  }

  provisioner "local-exec" {
    command = <<-EOT
      TOKEN=$(gcloud auth print-access-token \
        --impersonate-service-account='${var.resource_creator_identity}' \
        --quiet 2>/dev/null)

      REPORT_CONFIG_ID="migcenter-${local.random_id}-report-config"

      echo "Creating report configuration..."
      curl -s -o /dev/null \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
          \"displayName\": \"${var.mc_report_name}-config\",
          \"groupPreferencesetAssignments\": [
            {
              \"group\": \"projects/${local.project.project_id}/locations/${var.region}/groups/${local.group_all_name}\",
              \"preferenceSet\": \"projects/${local.project.project_id}/locations/${var.region}/preferenceSets/${local.pref_agg_name}\"
            },
            {
              \"group\": \"projects/${local.project.project_id}/locations/${var.region}/groups/${local.group_win_name}\",
              \"preferenceSet\": \"projects/${local.project.project_id}/locations/${var.region}/preferenceSets/${local.pref_mod_name}\"
            },
            {
              \"group\": \"projects/${local.project.project_id}/locations/${var.region}/groups/${local.group_lin_name}\",
              \"preferenceSet\": \"projects/${local.project.project_id}/locations/${var.region}/preferenceSets/${local.pref_mod_name}\"
            }
          ]
        }" \
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/reportConfigs?reportConfigId=$REPORT_CONFIG_ID" \
        || echo "WARNING: Report config creation failed (may already exist)."

      echo "Triggering report generation for '${var.mc_report_name}'..."
      curl -s -o /dev/null \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
          \"displayName\": \"${var.mc_report_name}\",
          \"type\": \"TOTAL_COST_OF_OWNERSHIP\"
        }" \
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/reportConfigs/$REPORT_CONFIG_ID/reports?reportId=migcenter-${local.random_id}-tco" \
        || echo "WARNING: Report generation failed — run manually from the Migration Center console."

      echo "Report generation triggered. Allow up to 5 minutes for the report to appear."
    EOT
  }

  depends_on = [null_resource.mc_preferences]
}
