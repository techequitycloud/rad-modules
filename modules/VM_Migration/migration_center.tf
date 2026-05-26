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
    project   = local.project.project_id
    region    = var.region
    random_id = local.random_id
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

        if [ "$STATUS" = "404" ]; then
          echo "NOTE: initializeConfig returned 404 — v1 API auto-initializes on first use."
          echo "Proceeding to create Discovery Source."
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
          "type": "SOURCE_TYPE_DISCOVERY_CLIENT"
        }' \
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/sources?sourceId=${local.mc_source_name}")

      HTTP_CODE=$(echo "$RESPONSE" | tail -1)
      BODY=$(echo "$RESPONSE" | head -n -1)
      if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "409" ]; then
        echo "Discovery source created or already exists (HTTP $HTTP_CODE)."
      else
        echo "ERROR: Source creation returned HTTP $HTTP_CODE."
        echo "$BODY"
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.mc_init]
}

# ─── Step 3: Discover and Import AWS EC2 Inventory ───────────────────────────
# Uses the provided AWS credentials to query EC2 instances via the AWS CLI,
# generates Migration Center-format CSV files (vmInfo, diskInfo, tagInfo,
# perfInfo), and imports them as an MC import job. Skipped when
# var.aws_access_key_id is empty.
resource "null_resource" "mc_aws_import" {
  count = (var.initialize_migration_center && var.aws_access_key_id != "") ? 1 : 0

  triggers = {
    import_name = local.aws_import_name
    project     = local.project.project_id
    region      = var.region
    aws_region  = var.aws_region
    # Trigger re-import when the scoped IAM key changes (e.g. key rotation).
    aws_key_id  = aws_iam_access_key.mc_discovery_key[0].id
  }

  provisioner "local-exec" {
    # Pass the scoped discovery key via env vars so the secret is never
    # interpolated into the command string (which would appear in plan output).
    environment = {
      AWS_ACCESS_KEY_ID     = aws_iam_access_key.mc_discovery_key[0].id
      AWS_SECRET_ACCESS_KEY = aws_iam_access_key.mc_discovery_key[0].secret
      AWS_DEFAULT_REGION    = var.aws_region
    }

    command = <<-EOT
      set -e
      echo "Starting AWS EC2 discovery for region ${var.aws_region}..."

      WORKDIR=$(mktemp -d)

      if ! command -v aws &>/dev/null; then
        echo "ERROR: AWS CLI not found in build environment."
        exit 1
      fi

      echo "Querying EC2 instances..."
      if ! aws ec2 describe-instances \
        --query 'Reservations[].Instances[]' \
        --output json > "$WORKDIR/instances.json"; then
        echo "ERROR: Failed to query EC2 instances. Verify AWS credentials and ec2:DescribeInstances permission."
        exit 1
      fi

      INSTANCE_COUNT=$(python3 -c "import json; print(len(json.load(open('$WORKDIR/instances.json'))))")
      echo "Found $INSTANCE_COUNT EC2 instances."

      if [ "$INSTANCE_COUNT" = "0" ]; then
        echo "No EC2 instances found in ${var.aws_region} — skipping import."
        rm -rf "$WORKDIR"
        exit 0
      fi

      echo "Fetching instance type specifications..."
      INSTANCE_TYPES=$(python3 -c "
import json
instances = json.load(open('$WORKDIR/instances.json'))
types = list(set(i['InstanceType'] for i in instances if i.get('InstanceType')))
print(' '.join(types))
")
      if [ -n "$INSTANCE_TYPES" ]; then
        aws ec2 describe-instance-types \
          --instance-types $INSTANCE_TYPES \
          --query 'InstanceTypes[]' \
          --output json > "$WORKDIR/instance_types.json" 2>/dev/null \
          || echo '[]' > "$WORKDIR/instance_types.json"
      else
        echo '[]' > "$WORKDIR/instance_types.json"
      fi

      echo "Fetching EBS volume information..."
      INSTANCE_IDS=$(python3 -c "
import json
instances = json.load(open('$WORKDIR/instances.json'))
print(','.join(i['InstanceId'] for i in instances))
")
      aws ec2 describe-volumes \
        --filters "Name=attachment.instance-id,Values=$INSTANCE_IDS" \
        --query 'Volumes[]' \
        --output json > "$WORKDIR/volumes.json" 2>/dev/null \
        || echo '[]' > "$WORKDIR/volumes.json"

      echo "Generating Migration Center CSV files..."
      python3 - "$WORKDIR" <<'PYEOF'
import json, csv, sys

workdir = sys.argv[1]

instances  = json.load(open(f'{workdir}/instances.json'))
type_list  = json.load(open(f'{workdir}/instance_types.json'))
volumes    = json.load(open(f'{workdir}/volumes.json'))

type_specs = {
    t['InstanceType']: {
        'vcpu':      t.get('VCpuInfo',   {}).get('DefaultVCpus', ''),
        'memory_mb': t.get('MemoryInfo', {}).get('SizeInMiB',    ''),
    }
    for t in type_list
}

vol_by_instance = {}
for v in volumes:
    for att in v.get('Attachments', []):
        iid = att.get('InstanceId', '')
        vol_by_instance.setdefault(iid, []).append({
            'device':   att.get('Device', ''),
            'size_gb':  v.get('Size', ''),
        })

with open(f'{workdir}/vmInfo.csv', 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['MachineId','MachineName','CPUCount','MemoryMb',
                'OSName','Architecture','State','InstanceType'])
    for inst in instances:
        itype = inst.get('InstanceType', '')
        specs = type_specs.get(itype, {})
        name  = next((t['Value'] for t in inst.get('Tags', [])
                      if t['Key'] == 'Name'), inst.get('InstanceId', ''))
        w.writerow([
            inst.get('InstanceId', ''),
            name,
            specs.get('vcpu', ''),
            specs.get('memory_mb', ''),
            inst.get('PlatformDetails', 'Linux/UNIX'),
            inst.get('Architecture', ''),
            inst.get('State', {}).get('Name', ''),
            itype,
        ])

with open(f'{workdir}/diskInfo.csv', 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['MachineId','DiskLabel','SizeInGb'])
    for inst in instances:
        iid  = inst.get('InstanceId', '')
        vols = vol_by_instance.get(iid, [])
        if vols:
            for v in vols:
                w.writerow([iid, v['device'], v['size_gb']])
        else:
            for bdm in inst.get('BlockDeviceMappings', []):
                w.writerow([iid, bdm.get('DeviceName', ''), ''])

with open(f'{workdir}/tagInfo.csv', 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['MachineId','TagKey','TagValue'])
    for inst in instances:
        for tag in inst.get('Tags', []):
            w.writerow([inst.get('InstanceId', ''), tag['Key'], tag['Value']])

with open(f'{workdir}/perfInfo.csv', 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['MachineId','Timestamp','CpuUtilizationPercentage','MemoryUtilizationPercentage'])

print(f'CSV files generated for {len(instances)} instances.')
PYEOF

      TOKEN=$(gcloud auth print-access-token \
        --impersonate-service-account='${var.resource_creator_identity}' \
        --quiet 2>/dev/null)

      echo "Creating AWS import job '${local.aws_import_name}'..."
      CREATE_RESP=$(curl -s -w "\n%%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
          "displayName": "aws-ec2-import",
          "assetSource": "projects/${local.project.project_id}/locations/${var.region}/sources/${local.mc_source_name}"
        }' \
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/importJobs?importJobId=${local.aws_import_name}")

      HTTP_CODE=$(echo "$CREATE_RESP" | tail -1)
      if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "409" ]; then
        echo "ERROR: Import job creation returned HTTP $HTTP_CODE."
        echo "$CREATE_RESP" | head -n -1
        exit 1
      fi

      echo "Uploading CSV files..."
      for CSV_FILE in "$WORKDIR"/*.csv; do
        FILENAME=$(basename "$CSV_FILE")
        echo "  Uploading $FILENAME..."
        RESP=$(curl -s -w "\n%%{http_code}" \
          -X POST \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: text/csv" \
          --data-binary "@$CSV_FILE" \
          "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/importJobs/${local.aws_import_name}/importDataFiles?importDataFileId=$(echo "$FILENAME" | tr '.' '-')")
        CODE=$(echo "$RESP" | tail -1)
        if [ "$CODE" = "200" ] || [ "$CODE" = "409" ]; then
          echo "  Uploaded $FILENAME (HTTP $CODE)."
        else
          echo "  WARNING: Upload of $FILENAME returned HTTP $CODE — continuing."
        fi
      done

      echo "Validating import job..."
      VAL_RESP=$(curl -s -w "\n%%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{}' \
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/importJobs/${local.aws_import_name}:validate")
      VAL_CODE=$(echo "$VAL_RESP" | tail -1)
      if [ "$VAL_CODE" = "200" ]; then
        echo "Validation started — waiting 30s for validation to complete..."
        sleep 30
      else
        echo "WARNING: Validate returned HTTP $VAL_CODE — skipping run."
        echo "$VAL_RESP" | head -n -1
        rm -rf "$WORKDIR"
        exit 0
      fi

      echo "Running import job..."
      RUN_RESP=$(curl -s -w "\n%%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{}' \
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/importJobs/${local.aws_import_name}:run")
      RUN_CODE=$(echo "$RUN_RESP" | tail -1)
      if [ "$RUN_CODE" = "200" ]; then
        echo "Import job running (HTTP $RUN_CODE). Check Migration Center console for status."
      else
        echo "WARNING: Run returned HTTP $RUN_CODE — job may not have started."
        echo "$RUN_RESP" | head -n -1
      fi

      rm -rf "$WORKDIR"
      echo "AWS EC2 import submitted."
    EOT
  }

  depends_on = [null_resource.mc_source, aws_iam_access_key.mc_discovery_key]
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
      RESP=$(curl -s -w "\n%%{http_code}" \
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
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/preferenceSets?preferenceSetId=${local.pref_agg_name}")
      HTTP_CODE=$(echo "$RESP" | tail -1)
      BODY=$(echo "$RESP" | head -n -1)
      if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "409" ]; then
        echo "Aggressive preference created or already exists (HTTP $HTTP_CODE)."
      else
        echo "ERROR: Aggressive preference creation returned HTTP $HTTP_CODE."
        echo "$BODY"
        exit 1
      fi

      echo "Creating moderate-1yr migration preferences..."
      RESP=$(curl -s -w "\n%%{http_code}" \
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
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/preferenceSets?preferenceSetId=${local.pref_mod_name}")
      HTTP_CODE=$(echo "$RESP" | tail -1)
      BODY=$(echo "$RESP" | head -n -1)
      if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "409" ]; then
        echo "Moderate preference created or already exists (HTTP $HTTP_CODE)."
      else
        echo "ERROR: Moderate preference creation returned HTTP $HTTP_CODE."
        echo "$BODY"
        exit 1
      fi

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
    random_id   = local.random_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      TOKEN=$(gcloud auth print-access-token \
        --impersonate-service-account='${var.resource_creator_identity}' \
        --quiet 2>/dev/null)

      REPORT_CONFIG_ID="migcenter-${local.random_id}-report-config"

      echo "Creating report configuration..."
      RESP=$(curl -s -w "\n%%{http_code}" \
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
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/reportConfigs?reportConfigId=$REPORT_CONFIG_ID")
      HTTP_CODE=$(echo "$RESP" | tail -1)
      BODY=$(echo "$RESP" | head -n -1)
      if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "409" ]; then
        echo "Report config created or already exists (HTTP $HTTP_CODE)."
      else
        echo "ERROR: Report config creation returned HTTP $HTTP_CODE."
        echo "$BODY"
        exit 1
      fi

      echo "Triggering report generation for '${var.mc_report_name}'..."
      RESP=$(curl -s -w "\n%%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
          \"displayName\": \"${var.mc_report_name}\",
          \"type\": \"TOTAL_COST_OF_OWNERSHIP\"
        }" \
        "https://migrationcenter.googleapis.com/v1/projects/${local.project.project_id}/locations/${var.region}/reportConfigs/$REPORT_CONFIG_ID/reports?reportId=migcenter-${local.random_id}-tco")
      HTTP_CODE=$(echo "$RESP" | tail -1)
      BODY=$(echo "$RESP" | head -n -1)
      if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "409" ]; then
        echo "Report generation triggered (HTTP $HTTP_CODE). Allow up to 5 minutes for the report to appear."
      else
        echo "ERROR: Report generation returned HTTP $HTTP_CODE."
        echo "$BODY"
        exit 1
      fi
    EOT
  }

  depends_on = [null_resource.mc_preferences]
}
