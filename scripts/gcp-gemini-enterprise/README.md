# gcp-gemini-enterprise.sh — Cymbal Pools Gemini Enterprise Demo

Interactive bash script that walks a trainer through preparing and running the
"Cymbal Pools" Gemini Enterprise demo: seeding demo content, standing up a
Gemini Enterprise app with Drive/Calendar connectors, deploying a custom ADK
agent to Vertex AI Agent Engine, and cueing the in-class prompts. It follows
the same menu/preview/create/delete pattern as the other scripts in this
directory (see `../gcp-istio-security/README.md` for the shared conventions).

## Why some steps only print instructions

Gemini Enterprise has a real REST surface (`discoveryengine.googleapis.com`,
documented under
[Gemini Enterprise API reference](https://docs.cloud.google.com/gemini/enterprise/docs/reference/rest))
for creating the app itself (`engines.create`) and registering a custom ADK
agent (`authorizations.create` + `assistants.agents.create`) — steps `3` and
most of `7` call it with `curl` instead of just printing instructions.
**Step 5 (Drive/Calendar connectors) was tried the same way and confirmed,
by testing against a real project, not to work**: `setUpDataConnector` has no
field for an OAuth client, so it cannot complete the connector's
authorization — only the console's "+ New data store" wizard has an
Authentication settings screen with Client ID/Secret fields and a "Verify
Auth" button that drives the OAuth popup. Step 5 prints that wizard's exact
screens/fields instead. Other pieces genuinely have no API at all: the
Identity Provider confirmation, the "Google Auth Platform" OAuth consent
screen + client (custom redirect URIs still require the console), Feature
Management toggles, Model Armor, and granting the "Agent User" role to end
users. Those stay as printed console instructions with a pause. `1`, `2`,
`6`, `8`, and the `curl` calls in `3`/`7` execute for real.

The `discoveryengine.googleapis.com` endpoints used here are `v1alpha`/`v1` —
still evolving. Each `curl` call is preceded by a warning to verify the field
names in the console if it fails; treat this script as a strong starting
point, not a guarantee, and rerun it against a real project before using it
live in front of a class.

## Prerequisites

- Google Cloud project with Gemini Enterprise, Vertex AI, and Discovery
  Engine available, and a project bucket (`<project>-bucket`) preloaded with
  the demo documents, a `pool party.png` image, and the `adk_to_ge/` agent
  source (as provisioned by the Qwiklabs environment).
- `gcloud` CLI authenticated as a project Owner or Editor.
- `python3` and `pip` available (Cloud Shell has both); the Agent Development
  Kit (`adk`) CLI is installed by step `6` into `requirements.txt`'s target
  environment.
- A second browser tab signed in with the same Qwiklabs student ID for all
  console/OAuth steps, per the lab's own guidance to avoid account collisions.

## Quick start

```bash
cd /path/where/you/want/working/files
./gcp-gemini-enterprise.sh
```

A menu appears that loops until you press `Q`. **Always start each session by
pressing `0`** to choose an execution mode and confirm the GCP project.

## Execution modes (option `0`)

| Reply | Mode | Behavior |
|-------|------|----------|
| `y` (default) | **Preview** | Prints commands/instructions without running them. |
| `n` | **Create** | Authenticates and executes each step, pausing for manual console work. |
| `d` | **Delete** | Best-effort teardown of what each step created. |

In Create / Delete mode the script runs `gcloud auth login`, asks for the
project ID, creates a service account `<project>@<project>.iam.gserviceaccount.com`
with `roles/owner`, drops the key at
`./gcp-gemini-enterprise/.<project>.json`, and creates a `gs://<project>`
bucket for backing up `.env`. Delete the cached key file to switch projects
later.

## Configuration (`.env`)

Created at `./gcp-gemini-enterprise/.env`. Edit values before running the
numbered steps, or let the script populate the OAuth and agent fields for you
as you complete each step:

| Variable | Default | Purpose |
|----------|---------|---------|
| `GCP_PROJECT` | current `gcloud` project | Target project ID. |
| `GCP_REGION` | `us-east4` | Region the ADK agent is deployed to on Agent Engine. |
| `GCS_BUCKET` | `<project>-bucket` | Bucket holding demo docs, the announcement image, and `adk_to_ge/`. |
| `APP_NAME` | `Cymbal Pools GE` | Gemini Enterprise app display name. |
| `APP_ID` | `cymbal-pools-ge` | Gemini Enterprise engine/app resource ID used by `engines.create`. |
| `GE_LOCATION` | `us` | The app's own Discovery Engine location (used by `engines.create`/`authorizations.create`). Data stores created in step 5's console wizard default to `global` independently of this. |
| `COMPANY_NAME` | `Cymbal Pools` | Company name for the app's Advanced Options. |
| `AGENT_DIR` | `adk_to_ge` | Local/bucket directory holding the ADK agent source. |
| `MODEL` | `gemini-3.5-flash` | Model used by the BigQuery agent's `.env`. |
| `OAUTH_CLIENT_ID` / `OAUTH_CLIENT_SECRET` | `NOT_SET` | Captured by step `4` after you create the OAuth client. |
| `REASONING_ENGINE` | `NOT_SET` | Captured by step `6` from the `adk deploy` output. |
| `AUTH_ID` | `bq-auth` | Resource ID for the Discovery Engine `Authorization` created in step `7`. |
| `AUTH_URI` | `NOT_SET` | Captured by step `7` from `construct_auth_uri.py`. |
| `AUTHORIZATION` | `NOT_SET` | Full resource name of the `Authorization` created by step `7`, referenced by the agent. |

## Menu walkthrough

Run options `1` → `8` once, in order, to stand up the environment, then use
`9` to validate and `11` any time during the live class as a prompt cue card.

### `(1) Enable APIs`
Enables `discoveryengine`, `aiplatform`, `iap`, `bigquery`, `storage`, `iam`,
and `cloudresourcemanager`. Delete mode leaves APIs enabled — other modules or
labs in the same project may depend on them, per this repo's API-enablement
convention.

### `(2) Prepare demo content`
Downloads the demo PDF/DOCX from `$GCS_BUCKET` and pauses with instructions to
upload them to Google Drive by hand (Drive upload needs a user OAuth grant,
not a service account).

### `(3) Create Gemini Enterprise app & identity provider`
Calls `engines.create` (`appType: APP_TYPE_INTRANET`) to create the app with
`$APP_NAME`/`$APP_ID`/`$COMPANY_NAME` and no data stores attached yet, then
prints the Identity Provider steps, which have no API: go to **Settings >
Authentication** and confirm Google Identity for the **`global`** row. This
setting is per-location (the page lists `global`, `us`, `eu`, ...), and it
matters because **step 5's data stores default to the `global` multi-region
regardless of the app's own `$GE_LOCATION` setting** — confirmed by testing.
ACLed connectors (Drive/Calendar) check the IdP for whichever location the
data store actually lands in, so `global` is what needs to be configured
unless you deliberately pick a different location in step 5's wizard.
Skipping this produces `FAILED_PRECONDITION: IdP must be selected before
creating an ACLed Data Connector`. Delete mode calls `engines.delete`.

### `(4) Create OAuth consent screen & OAuth client`
Console-only — custom redirect URIs on a Web-application OAuth client still
require the "Google Auth Platform" UI. Prints the steps, including the two
required redirect URIs, then prompts you to paste back the resulting Client
ID/Secret so later steps can reuse them.

### `(5) Create data stores (Drive, Calendar, Announcements)`
Console-only, and deliberately so (see above). Prints the "+ New data store"
wizard steps for Drive and Calendar — Source (search and pick the first-party
card) → Data/Authentication settings (Client ID/Secret from step `4`, Verify
Auth, complete the OAuth popup) → Advanced options ("Supports All Drives" for
Drive) → Actions (select all) → Configuration (leave Location at the default
`global`, name the connector) — then the Announcements data store/content
steps with `Start Time`/`End Time` computed as today/tomorrow.

### `(6) Deploy custom ADK agent to Agent Engine`
Fully automated: downloads `$AGENT_DIR` from the bucket, installs
`requirements.txt`, writes `bigquery_agent/.env`, and runs
`adk deploy agent_engine` (~5–10 minutes). Parses the `reasoningEngines`
resource name out of the deploy log into `.env`. Delete mode deletes it via
the Vertex AI Python SDK (`vertexai.agent_engines.delete`) — there is no
`gcloud ai reasoning-engines`/`agent-engines` command group.

### `(7) Construct auth URI & register agent in Gemini Enterprise`
Patches `OAUTH_CLIENT_ID` into `construct_auth_uri.py` and runs it to build
the Authorization URI (verify the substitution still matches the shipped
script before trusting it), then calls `authorizations.create` to register
the OAuth client with Discovery Engine and
`assistants.agents.create` to register the BigQuery agent against the
deployed reasoning engine and that authorization. Only granting the agent's
"Agent User" role to All Users has no confirmed API and stays a console step.

### `(8) Grant IAM permissions`
Runs `gcloud beta services identity create` to materialize the AI Platform
Reasoning Engine service agent, then grants it `roles/aiplatform.user`,
`roles/bigquery.user`, and `roles/bigquery.dataEditor`. The service agent
email is derived from the project number
(`service-<number>@gcp-sa-aiplatform-re.iam.gserviceaccount.com`); if a
binding fails, confirm the exact principal under **IAM & Admin > Include
Google-provided grants** and grant it manually.

### `(9) Validate the setup`
Manual by design. Prints the Feature Management, app preview, connector, and
Deep Research checks from the lab's validation task.

### `(10) Configure Feature Management & Model Armor`
Console-only. Prints the Feature Management toggles and the Model Armor
template lookup/enable steps.

### `(11) Show in-class demo prompts`
Pure cue card — no execution. Prints every prompt from the lab's "In-Class
Demos" section (general queries, enterprise search, Deep Research, Agent
Designer, the BigQuery agent conversation, and the Model Armor / harassment /
prompt-injection test prompts) so you can read and copy-paste them live
without switching back to the PDF.

### `(R)` / `(G)` / `(Q)`
- `R` — show maintainer credits.
- `G` — launch a bundled Cloud Shell tutorial, if `.tutorial.md` exists next to
  the script (not included by default).
- `Q` — quit.

## Working files

```
./gcp-gemini-enterprise/
├── .env                       # current configuration, including captured OAuth/agent IDs
├── .<GCP_PROJECT>.json        # service-account key
├── *.pdf / *.docx             # demo documents downloaded in step 2
├── engine_create.json         # engines.create response from step 3
├── adk_deploy.log             # captured `adk deploy agent_engine` output
├── adk_to_ge/                 # ADK agent source downloaded in step 6
└── authorization.json / agent_create.json       # authorizations/agents.create responses from step 7
```

`.env` is also backed up to `gs://<GCP_PROJECT>/gcp-gemini-enterprise.sh.env`.

## Cleanup

1. Option `0` → `d` (delete mode).
2. Run `7` to remove the Authorization resource record, then `8` to remove
   the IAM bindings, then `6` to delete the Agent Engine deployment (and
   manually remove the BigQuery Agent + Authorization from the Gemini
   Enterprise console — deleting the reasoning engine does not deregister
   the agent that points at it).
3. Run `5` and `3` in delete mode to remove the data connectors and the app.
4. Manually remove the OAuth client/brand from Google Auth Platform and the
   Model Armor template — steps `4` and `10` print reminders but do not
   delete console-managed resources.
5. Delete `./gcp-gemini-enterprise/` and the service-account key file.
