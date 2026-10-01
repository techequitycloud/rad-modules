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

# Custom ADK agent (Task 4 of the lab): deploys adk_to_ge/bigquery_agent to
# Vertex AI Agent Runtime (Agent Engine) and grants its service agent access
# to BigQuery and Vertex AI.
#
# Registering the agent in Gemini Enterprise stays manual: it needs the OAuth
# client from the Google Auth Platform console, and "Grant All Users the Agent
# User role" has no API. The reasoning engine resource name the registration
# form asks for is exported as the reasoning_engine output.

locals {
  engine_file = "${path.module}/scripts/reasoning_engine.txt"
  agent_source_hash = sha1(join("", [
    for f in local.adk_files : filesha1("${path.module}/adk_to_ge/${f}")
  ]))
}

resource "null_resource" "deploy_adk_agent" {
  count = var.deploy_adk_agent ? 1 : 0

  # Everything the destroy provisioner needs must live here — only
  # self.triggers is available at destroy time.
  triggers = {
    project_id   = local.project.project_id
    region       = var.region
    display_name = local.agent_display_name
    impersonate  = var.resource_creator_identity
    engine_file  = local.engine_file
    source_hash  = local.agent_source_hash
    model        = var.agent_model
    auth_id      = var.agent_auth_id
    dataset      = google_bigquery_dataset.cymbal_pools.dataset_id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      PROJECT_ID    = self.triggers.project_id
      REGION        = self.triggers.region
      DISPLAY_NAME  = self.triggers.display_name
      IMPERSONATE   = self.triggers.impersonate
      ENGINE_FILE   = self.triggers.engine_file
      MODEL         = self.triggers.model
      AUTH_ID       = self.triggers.auth_id
      BQ_DATASET    = self.triggers.dataset
      MODEL_LOC     = var.agent_model_location
      AGENT_SRC     = "${path.module}/adk_to_ge"
      DEPLOY_SCRIPT = "${path.module}/scripts/adk_deploy.py"
    }
    command = <<-EOT
      set -eo pipefail
      command -v python3 >/dev/null || { echo "ERROR: python3 is required to deploy the ADK agent" >&2; exit 1; }

      # Paths arrive relative to the module (kept relative in triggers so they
      # do not differ between runners); pin them before cd-ing into $WORK.
      ENGINE_FILE="$(cd "$(dirname "$ENGINE_FILE")" && pwd)/$(basename "$ENGINE_FILE")"
      DEPLOY_SCRIPT="$(cd "$(dirname "$DEPLOY_SCRIPT")" && pwd)/$(basename "$DEPLOY_SCRIPT")"
      AGENT_SRC="$(cd "$AGENT_SRC" && pwd)"

      VENV="$HOME/.local/ge-adk-venv"
      if [ ! -x "$VENV/bin/python" ]; then
        python3 -m venv "$VENV"
      fi
      "$VENV/bin/pip" install --quiet --upgrade pip
      "$VENV/bin/pip" install --quiet -r "$AGENT_SRC/requirements.txt"

      WORK=$(mktemp -d)
      trap 'rm -rf "$WORK"' EXIT
      cp -R "$AGENT_SRC/bigquery_agent" "$WORK/"
      rm -rf "$WORK/bigquery_agent/__pycache__"
      cat > "$WORK/bigquery_agent/.env" <<ENV
      GOOGLE_GENAI_USE_VERTEXAI=TRUE
      GOOGLE_CLOUD_PROJECT=$PROJECT_ID
      MODEL_LOCATION=$MODEL_LOC
      MODEL=$MODEL
      BQ_DATASET=$BQ_DATASET
      ENV
      # Agent Runtime rejects an env var with an empty value (400 "env[N].value:
      # Required field is not set"), so AUTH_ID is written only when set.
      if [ -n "$AUTH_ID" ]; then
        echo "AUTH_ID=$AUTH_ID" >> "$WORK/bigquery_agent/.env"
      fi

      echo "Deploying '$DISPLAY_NAME' to Agent Runtime in $REGION (5-10 minutes)..."
      cd "$WORK"
      IMPERSONATE_SERVICE_ACCOUNT="$IMPERSONATE" GOOGLE_CLOUD_PROJECT="$PROJECT_ID" \
        "$VENV/bin/python" "$DEPLOY_SCRIPT" deploy agent_engine \
          --project "$PROJECT_ID" \
          --region "$REGION" \
          --display_name "$DISPLAY_NAME" \
          --description "Queries pool installation data." \
          bigquery_agent 2>&1 | tee "$WORK/deploy.log"

      ENGINE=$(grep -oE 'projects/[^/ ]+/locations/[^/ ]+/reasoningEngines/[0-9]+' "$WORK/deploy.log" | tail -1)
      if [ -z "$ENGINE" ]; then
        echo "ERROR: could not find the reasoningEngines resource name in the deploy output" >&2
        exit 1
      fi
      if ! grep -q "Deployed to Agent Platform" "$WORK/deploy.log"; then
        echo "ERROR: engine $ENGINE was created but the code deploy did not complete" >&2
        exit 1
      fi
      printf '%s' "$ENGINE" > "$ENGINE_FILE"
      echo "Agent deployed: $ENGINE"
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    environment = {
      PROJECT_ID   = self.triggers.project_id
      REGION       = self.triggers.region
      DISPLAY_NAME = self.triggers.display_name
      IMPERSONATE  = self.triggers.impersonate
      ENGINE_FILE  = self.triggers.engine_file
    }
    command = <<-EOT
      set +e
      IMP_FLAG=""
      [ -n "$IMPERSONATE" ] && IMP_FLAG="--impersonate-service-account=$IMPERSONATE"
      TOKEN=$(gcloud auth print-access-token $IMP_FLAG 2>/dev/null)
      API="https://$REGION-aiplatform.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/reasoningEngines"
      # Look engines up by display name (it embeds the deployment ID) rather
      # than trusting the local file, which does not survive between Cloud
      # Build runs.
      ENGINES=$(curl -sS -H "Authorization: Bearer $TOKEN" "$API?pageSize=100" | \
        python3 -c "import json,sys,os; d=json.load(sys.stdin); print('\n'.join(e['name'] for e in d.get('reasoningEngines',[]) if e.get('displayName')==os.environ['DISPLAY_NAME']))" 2>/dev/null)
      if [ -z "$ENGINES" ]; then
        echo "No Agent Runtime engine named '$DISPLAY_NAME' found -- nothing to delete"
      fi
      for E in $ENGINES; do
        echo "Deleting $E"
        curl -sS -X DELETE -H "Authorization: Bearer $TOKEN" \
          "https://$REGION-aiplatform.googleapis.com/v1/$E?force=true" >/dev/null \
          || echo "Warning: failed to delete $E -- remove it under Vertex AI > Agent Runtime"
      done
      rm -f "$ENGINE_FILE"
      echo "Reminder: remove the BigQuery Agent registration from the Gemini Enterprise app if you created one."
      exit 0
    EOT
  }

  depends_on = [
    google_project_service.enabled_services,
    google_bigquery_job.seed_installation_requests,
  ]
}

# The AI Platform Reasoning Engine service agent only exists after the first
# engine is created in the project, so these bindings must follow the deploy.
resource "google_project_iam_member" "reasoning_engine_roles" {
  for_each = var.deploy_adk_agent ? toset([
    "roles/aiplatform.user",
    "roles/bigquery.user",
    "roles/bigquery.dataEditor",
  ]) : toset([])

  project = local.project.project_id
  role    = each.value
  member  = "serviceAccount:${local.reasoning_engine_sa}"

  depends_on = [null_resource.deploy_adk_agent]
}
