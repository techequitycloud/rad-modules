# Gemini Enterprise Demo Environment

This module prepares a Google Cloud project for an **instructor-led demonstration of Gemini Enterprise**, built around the fictional **Cymbal Pools** company. It is a **standalone module**: it creates its own bucket, dataset, agent and app, and does not depend on any shared foundation infrastructure.

On apply the module creates the Gemini Enterprise app with Google Identity configured, a searchable data store of Cymbal Pools documents, a content bucket (Drive documents, announcement image, pH-table image, BigQuery seed data, ADK agent source), a BigQuery `installation_requests` table, a custom ADK BigQuery agent on Vertex AI Agent Runtime with the IAM it needs, and a Model Armor template. The instructor then completes the handful of steps that need an interactive Google Workspace sign-in (Drive/Calendar connectors, OAuth client, agent registration) and runs the demos.

This guide covers the cloud services the module provisions and how to explore and operate them from the Google Cloud Console and the command line. The full pre-class checklist and in-class demo script are in the [Lab Guide](https://docs.radmodules.dev/docs/labs/Gemini_Enterprise).

Resources carry the deployment suffix `<id>`: bucket `<project>-ge-<id>`, app `cymbal-pools-ge-<id>`, data store `cymbal-pools-docs-<id>`, Model Armor template `cymbal-pools-ma-<id>`, and Agent Runtime engine "BigQuery Pool Data Agent (<id>)".

---

## 1. Overview

| Capability | Google Cloud service | Notes |
|---|---|---|
| Agentic workspace app | Gemini Enterprise (Discovery Engine) | `APP_TYPE_INTRANET` app, Enterprise search tier with the LLM add-on, company name "Cymbal Pools" |
| Identity | Gemini Enterprise ACL config | Google Identity (`GSUITE`) selected for the app's location |
| Company documents | Discovery Engine data store | Cloud Storage-backed, unstructured; indexes the brochure PDF and analysis DOCX |
| Demo content | Cloud Storage | Drive documents, announcement image, pH-table image, seed CSV, `adk_to_ge/` agent source |
| Pool installation data | BigQuery | `cymbal_pools.installation_requests`, seeded with 60 sample rows |
| Custom agent | Vertex AI Agent Runtime (Agent Engine) + ADK | BigQuery agent deployed with `adk deploy agent_engine`, running as `resource_creator_identity` |
| AI safety | Model Armor | Template with SDP, RAI, prompt-injection/jailbreak and malicious-URI filters |

**Things to know up front:**

- **Gemini Enterprise must be activated in the project first.** On a project that has never used it, open Gemini Enterprise in the console once and click **Start free trial**. Enabling `discoveryengine.googleapis.com` is not the same thing, and app creation fails until the trial is started. Set `create_gemini_enterprise_app = false` to create the app by hand instead.
- **Several steps are deliberately manual.** The Google Drive and Calendar connectors and the OAuth consent screen/client need interactive OAuth flows that only the console provides. Registering the BigQuery agent needs that OAuth client, and granting the agent's "Agent User" role to all users has no API. Announcements, Feature Management toggles and attaching Model Armor to the assistant are demoed live.
- **Everything shares one Gemini Enterprise location.** The app, its data stores, the identity provider, the Drive/Calendar connectors and the agent registration must all live in `ge_location` (`global` by default).
- **The agent deploy runs Python on the Terraform runner.** `null_resource.deploy_adk_agent` creates a virtualenv under `$HOME/.local/ge-adk-venv`, installs `google-adk`, and runs `adk deploy agent_engine` through a small wrapper (`scripts/adk_deploy.py`) that makes the ADK impersonate `resource_creator_identity`. The deploy takes 5–10 minutes.
- **The demo content is original.** Cymbal Pools is fictional; the PDF, DOCX, images and CSV in `assets/` were written for this module and can be regenerated with `assets/generate_assets.py`.

---

## 2. Google Cloud Services & How to Explore Them

All commands assume these are set to match your deployment. Resource names are reported in the deployment [Outputs](#5-outputs).

```bash
export PROJECT="<project_id>"
export REGION="us-central1"      # region (Agent Runtime)
export GE_LOCATION="global"      # ge_location
export ID="<deployment_id>"
export GE_HOST=discoveryengine.googleapis.com   # use ${GE_LOCATION}-discoveryengine.googleapis.com for us/eu
```

### A. Gemini Enterprise app, identity and data store

The app (`cymbal-pools-ge-<id>`) is an intranet-type engine with the Enterprise search tier and LLM add-on. Google Identity is set as the identity provider for `ge_location` so ACL-enforced connectors (Drive, Calendar) can be created there. The `cymbal-pools-docs-<id>` data store is attached to the app at creation and indexes the documents under `gs://<bucket>/drive/`.

- **Console:** **Gemini Enterprise** → Apps (set the location filter to `ge_location` or *All locations*) → **Cymbal Pools GE**. Connected data stores, Integration, Agents and Configurations are in the app's left nav.
- **CLI:**
  ```bash
  TOKEN=$(gcloud auth print-access-token)
  # The app
  curl -s -H "Authorization: Bearer $TOKEN" -H "X-Goog-User-Project: $PROJECT" \
    "https://$GE_HOST/v1/projects/$PROJECT/locations/$GE_LOCATION/collections/default_collection/engines/cymbal-pools-ge-$ID"
  # Data stores in the location (the Drive/Calendar/Announcements ones appear here once created)
  curl -s -H "Authorization: Bearer $TOKEN" -H "X-Goog-User-Project: $PROJECT" \
    "https://$GE_HOST/v1/projects/$PROJECT/locations/$GE_LOCATION/collections/default_collection/dataStores"
  # Documents indexed from the bucket
  curl -s -H "Authorization: Bearer $TOKEN" -H "X-Goog-User-Project: $PROJECT" \
    "https://$GE_HOST/v1/projects/$PROJECT/locations/$GE_LOCATION/collections/default_collection/dataStores/cymbal-pools-docs-$ID/branches/default_branch/documents"
  ```

### B. Cloud Storage — demo content

| Object | Used for |
|---|---|
| `drive/Cymbal Pools Convention Brochure.pdf` | Upload to Google Drive; "Summarize @" file-targeting demo |
| `drive/Cymbal Pools Pool Installation Analysis.docx` | Upload to Google Drive; "how do we conduct a pool site inspection?" enterprise search demo |
| `pool party.png` | Image URL of the "Annual pool party" announcement (public-read when `public_announcement_image = true`) |
| `pH table.png` | Paste into the omnibar for the "Convert this image to tabular data" demo |
| `bigquery/installation_requests.csv` | Seed data loaded into BigQuery |
| `adk_to_ge/` | ADK agent source (`bigquery_agent/`, `construct_auth_uri.py`, `requirements.txt`) |

- **Console:** **Cloud Storage** → Buckets → `<project>-ge-<id>` (direct link in the `drive_documents_console_url` output).
- **CLI:**
  ```bash
  gcloud storage ls -r "gs://$PROJECT-ge-$ID/"
  gcloud storage cp "gs://$PROJECT-ge-$ID/drive/*" .           # the two Drive documents
  gcloud storage cp -r "gs://$PROJECT-ge-$ID/adk_to_ge" .      # the agent source
  curl -sI "https://storage.googleapis.com/$PROJECT-ge-$ID/pool%20party.png" | head -1   # expect 200 if public
  ```

### C. BigQuery — installation requests

`cymbal_pools.installation_requests` holds residential pool installation requests: `request_id`, `request_date`, `length_m`, `width_m`, `depth_m`, `has_hot_tub`, `has_waterfall`, `zip_code`, `customer_phone`, `customer_email`. It is seeded by a BigQuery load job whose ID embeds the CSV's hash, so rows the agent inserts during a demo survive later applies unless the seed CSV itself changes.

- **Console:** **BigQuery** → Explorer → `<project>` → `cymbal_pools` → `installation_requests`. Queries the agent runs appear under **Job history → Project history**.
- **CLI:**
  ```bash
  bq show --schema --format=prettyjson "$PROJECT:cymbal_pools.installation_requests"
  bq query --use_legacy_sql=false \
    "SELECT COUNT(*) AS requests, ROUND(AVG(length_m*width_m*depth_m),1) AS avg_volume_m3 FROM \`$PROJECT.cymbal_pools.installation_requests\`"
  ```

### D. Vertex AI Agent Runtime — BigQuery agent

The ADK agent (`adk_to_ge/bigquery_agent`) uses the ADK `BigQueryToolset` with write mode allowed and instructions that restrict it to `SELECT`/`INSERT` on `installation_requests`. By default it queries as the **AI Platform Reasoning Engine service agent** (`service-<number>@gcp-sa-aiplatform-re.iam.gserviceaccount.com`), which the module grants `roles/aiplatform.user`, `roles/bigquery.user` and `roles/bigquery.dataEditor`. Setting `agent_auth_id` makes it use the Gemini Enterprise user's OAuth token instead (see [Behaviour](#3-behaviour)).

- **Console:** **Vertex AI** → Agent Runtime (select `region`) → "BigQuery Pool Data Agent (<id>)".
- **CLI:**
  ```bash
  TOKEN=$(gcloud auth print-access-token)
  curl -s -H "Authorization: Bearer $TOKEN" \
    "https://$REGION-aiplatform.googleapis.com/v1/projects/$PROJECT/locations/$REGION/reasoningEngines" \
    | python3 -c "import json,sys; [print(e['name'], '|', e.get('displayName')) for e in json.load(sys.stdin).get('reasoningEngines',[])]"
  gcloud projects get-iam-policy "$PROJECT" --flatten="bindings[].members" \
    --filter="bindings.members:gcp-sa-aiplatform-re" --format="table(bindings.role)"
  ```

### E. Model Armor

One template, `cymbal-pools-ma-<id>`, in `model_armor_location` (defaults to `ge_location`, except that a `global` app gets a `us` template: Model Armor rejects templates in `global` with `UNSUPPORTED_REQUEST_LOCATION`, and a `global` app's assistant accepts a `us` template, both confirmed live). Each filter maps to a group of the lab's test prompts: basic Sensitive Data Protection (card numbers, credentials), responsible-AI filters (harassment, hate speech, dangerous, sexually explicit) at `model_armor_confidence`, prompt-injection/jailbreak detection, and malicious-URI detection. Enforcement is `INSPECT_AND_BLOCK`. The module does **not** attach it to the assistant; the instructor does that live under **Configurations → Assistant → Enable Model Armor**.

- **Console:** **Security → Model Armor** → `cymbal-pools-ma-<id>`.
- **CLI:**
  ```bash
  gcloud model-armor templates describe "cymbal-pools-ma-$ID" --location="$GE_LOCATION" --project="$PROJECT"
  ```

---

## 3. Behaviour

**What gets provisioned on apply.** In dependency order: the project APIs (Discovery Engine, Vertex AI, BigQuery, Cloud Storage, IAM and IAM Credentials, Resource Manager, Service Usage, Model Armor, Cloud Build, Logging, Monitoring, Cloud Trace); the content bucket and its objects; the BigQuery dataset, table and seed load job; the Google Identity ACL config; the Discovery Engine service agent (with read access to the bucket), the document data store, and a `documents:import` call; the Gemini Enterprise app; the Model Armor template; and finally the agent deploy followed by the Reasoning Engine service agent's IAM bindings. Those bindings must come after the deploy because that service agent only exists once the project's first engine has been created.

**Document import.** Discovery Engine has no Terraform resource for importing documents, so `null_resource.import_cymbal_docs` calls `documents:import` with `gs://<bucket>/drive/*` and retries for up to about two minutes while the service agent's bucket grant propagates. The import is asynchronous: apply returns once it has *started*, and indexing finishes a few minutes later. The import re-runs when either document's content changes.

**Agent deploy and identity.** `adk deploy agent_engine` has no impersonation option, so the module runs it through `scripts/adk_deploy.py`. That wrapper replaces `google.auth.default()` with short-lived impersonated credentials for `resource_creator_identity` before the ADK loads, so the engine is created by the same identity as every other resource. With `resource_creator_identity` empty it behaves exactly like `adk`. The wrapper writes the resulting `reasoningEngines` resource name to `scripts/reasoning_engine.txt`, and the `reasoning_engine` output reads that file.

**Model location vs. deploy region.** `adk deploy --region X` forces `GOOGLE_CLOUD_LOCATION=X` inside the deployed container, overriding any value in the agent's `.env`. (The original lab's `GOOGLE_CLOUD_LOCATION=global` line is therefore ignored.) The module passes the model location separately as `MODEL_LOCATION` (`agent_model_location`, default `global`), and the agent applies it before the model client is created.

**Per-user vs. service-agent BigQuery access.** With `agent_auth_id` empty (default) the agent queries as the Reasoning Engine service agent, so the demo works whether or not the agent was registered with an OAuth authorization. Set `agent_auth_id` to the Gemini Enterprise Authorization ID (e.g. `bq-auth`) to have queries run as the signed-in user; the agent then reads the token Gemini Enterprise stores in session state under that key. Changing it redeploys the agent.

**Console changes are preserved.** The app ignores drift on `data_store_ids`, `features` and `knowledge_graph_config`. As a result, connectors the instructor attaches and Feature Management toggles (Agent Designer, image model, session sharing) are not reverted by a later apply.

**Manual follow-up the instructor performs.** Upload the Drive documents, create the Drive/Calendar connectors and the Announcements data store, create the OAuth consent screen and Web client, register the BigQuery agent (optionally with an Authorization), grant All Users the Agent User role, confirm Workforce Identity on the app's Integration page, and enable Feature Management options. All of these are listed step by step in the Lab Guide.

**Cleanup behaviour.** Destroy removes the app, data store, ACL config, bucket (force-destroyed with its contents), BigQuery dataset (with contents), Model Armor template, IAM bindings, and the Agent Runtime engine. The engine's destroy provisioner finds it by display name rather than the local file, since that file does not survive between platform runs. Destroy does **not** remove anything created by hand. Deleting the app does not delete the data stores attached to it, so the Drive, Calendar and Announcements data stores must be deleted from **Gemini Enterprise → Data stores** afterwards. The same applies to the OAuth client and consent screen, the Authorization resource, and the files uploaded to Google Drive. The agent registration lives inside the app and goes with it. APIs are left enabled.

---

## 4. Configuration Variables

Variables are grouped exactly as they appear on the deployment platform.

### Group 1 — Project & Location

| Variable | Default | Description |
|---|---|---|
| `project_id` | _(required)_ | Target project. Must already exist. For Qwiklabs, the lab project with the student account, so connectors and the app share one Workspace identity. |
| `region` | `us-central1` | Agent Runtime region for the ADK agent. Must be permitted by any `constraints/gcp.resourceLocations` policy. |

### Group 2 — Gemini Enterprise App

| Variable | Default | Description |
|---|---|---|
| `create_gemini_enterprise_app` | `true` | Create the app and the Cymbal Pools document data store. Needs the free trial (or a license) started first. |
| `ge_location` | `global` | `global`, `us` or `eu`. App, data stores, IdP, connectors and agent registration must all share it. |
| `app_display_name` | `Cymbal Pools GE` | App display name. |
| `company_name` | `Cymbal Pools` | Company name on the app (Advanced Options). |
| `configure_google_identity` | `true` | Select Google Identity as the IdP for `ge_location`. Required before Drive/Calendar connectors. |

### Group 3 — Demo Content

| Variable | Default | Description |
|---|---|---|
| `bucket_location` | `US` | Location of the content bucket. |
| `public_announcement_image` | `true` | Make only `pool party.png` public-read so the announcement renders for every user. |
| `bq_dataset_id` | `cymbal_pools` | BigQuery dataset for `installation_requests`. |
| `bq_location` | `US` | BigQuery dataset location. |

### Group 4 — Custom ADK Agent

| Variable | Default | Description |
|---|---|---|
| `deploy_adk_agent` | `true` | Deploy the BigQuery agent to Agent Runtime and grant its service agent Vertex AI User, BigQuery User and BigQuery Data Editor. |
| `agent_display_name` | `BigQuery Pool Data Agent` | Agent Runtime display name; the deployment ID is appended. |
| `agent_model` | `gemini-3.5-flash` | Model the agent uses. Changing it redeploys the agent as a new engine. |
| `agent_model_location` | `global` | Vertex AI location for model calls. |
| `agent_auth_id` | _(empty)_ | Gemini Enterprise Authorization ID; when set, queries run as the signed-in user. |

### Group 5 — Model Armor

| Variable | Default | Description |
|---|---|---|
| `create_model_armor_template` | `true` | Create the demo Model Armor template. |
| `model_armor_location` | _(empty → `ge_location`, with `global` → `us`)_ | Template location. Model Armor has no `global` templates. |
| `model_armor_confidence` | `MEDIUM_AND_ABOVE` | Blocking threshold for RAI and prompt-injection filters (`LOW_AND_ABOVE`, `MEDIUM_AND_ABOVE`, `HIGH`). |

---

## 5. Outputs

| Output | Description |
|---|---|
| `deployment_id` | The deployment suffix used in resource names. |
| `project_id` | GCP project ID. |
| `demo_bucket` | Content bucket name. |
| `drive_documents_console_url` | Console page listing the two documents to upload to Google Drive. |
| `agent_source_copy_cmd` | `gcloud storage cp -r` command to fetch `adk_to_ge/` into Cloud Shell. |
| `announcement_image_url` | Image URL for the "Annual pool party" announcement. |
| `ph_table_image_url` | Authenticated URL of the pH table image for the image-to-table demo. |
| `gemini_enterprise_location` | The location to use for connectors and agent registration. |
| `gemini_enterprise_app_id` | Engine ID of the app (`not created` when disabled). |
| `gemini_enterprise_console_url` | Gemini Enterprise console page for the project. |
| `cymbal_docs_data_store` | Resource name of the Cymbal Pools Documents data store. |
| `bigquery_table` | Fully qualified `installation_requests` table. |
| `reasoning_engine` | Agent Runtime resource name to paste into **Agents → Add agent**. |
| `model_armor_template` | Template resource name to paste into **Configurations → Assistant → Enable Model Armor**. |
| `oauth_redirect_uris` | The two redirect URIs to add to the Web OAuth client used by the connectors and the agent's authorization. |

---

## 6. Configuration Pitfalls & Sensible Defaults

> Risk: **Critical** (data loss / outage / security) — **High** (service degraded) —
> **Medium** (cost or partial degradation) — **Low** (minor).

| Setting | Sensible value | Risk | Consequence if wrong |
|---|---|---|---|
| `deployment_id` | set once | Critical | Embedded in every resource name. Changing it recreates the app (losing hand-attached connectors and agent registrations), bucket, data store and agent. |
| `create_gemini_enterprise_app` | `true` | High | If app creation fails with a licensing error, Gemini Enterprise is not activated in the project: start the free trial in the console and redeploy, or set `false` and create the app by hand. (Not needed on the Qwiklabs project this was tested against.) |
| `agent_model` | a model allowed by `constraints/vertexai.allowedModels` | High | Lab projects can restrict or deny all Vertex AI models. The agent still deploys, but every query fails with `FAILED_PRECONDITION ... disallowed Gen AI model`. Check the effective policy before class. |
| `ge_location` | `global` (or `us` on quota-limited sandboxes) | High | Connectors and the agent registration must be in the same location as the app, and a mismatch is rejected. Some sandbox projects have a custom-agent quota of 0 at `global`; use `us` there. Changing it recreates the app. |
| `configure_google_identity` | `true` | High | Without an IdP for the location, the Drive/Calendar connector wizard fails with "IdP must be selected before creating an ACLed Data Connector". |
| `region` | a region allowed by org policy | High | `constraints/gcp.resourceLocations` can reject Agent Runtime in the default region with a 412; pick an allowed region. |
| `public_announcement_image` | `true`, or `false` under public-access prevention | Medium | With `constraints/storage.publicAccessPrevention` enforced, the public ACL fails with a 412. Set `false` and use an image hosted elsewhere for the announcement. |
| `agent_model` / `agent_auth_id` | set before registering the agent | Medium | Either change redeploys the agent as a **new** engine, so the Gemini Enterprise registration pointing at the old `reasoning_engine` must be re-created. |
| `agent_model_location` | set before the first deploy | Low | It is passed to the agent at deploy time but is not one of the deploy's triggers, so changing it on an existing deployment does nothing until something that *is* a trigger (`agent_model`, `agent_auth_id`, `agent_display_name`, `region` or the agent source) redeploys the agent. |
| `agent_auth_id` | empty unless demoing per-user access | Medium | When set, queries run as the signed-in user, who then needs BigQuery access on the dataset; an unregistered or mismatched Authorization ID gives the agent no credentials. |
| `enable_services` | `true` | High | If the required APIs are not already enabled and this is `false`, resource creation fails immediately. |
| `model_armor_confidence` | `MEDIUM_AND_ABOVE` | Low | `HIGH` may let some of the lab's milder test prompts through; `LOW_AND_ABOVE` may block ordinary demo prompts. |

---

For the full instructor walkthrough (pre-class checklist, connector and agent registration steps, and the in-class demo prompts), see the **[Lab Guide](https://docs.radmodules.dev/docs/labs/Gemini_Enterprise)**.
