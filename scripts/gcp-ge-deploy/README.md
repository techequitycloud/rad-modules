# gcp-ge-deploy.sh — Deploying Gemini Enterprise Course Demo

Menu-driven companion script for the "Deploying Gemini Enterprise" training
course. It follows the same menu / preview / create / delete pattern as the
other scripts in this directory (see `../gcp-gemini-cymbalpools/README.md`
and `../gcp-cxas-scrapi/README.md` for the shared conventions) and reuses
several patterns directly from `gcp-gemini-cymbalpools.sh` (Gemini Enterprise
app creation, data connectors, ADK-agent deploy-and-register). Each numbered
menu option is tagged with the course module it demonstrates — `[M1]` and
`[M2]` through `[M9]` — so a trainer can jump from a slide deck straight to
the matching hands-on step.

Module coverage:

| Tag | Module | Steps |
|---|---|---|
| M1 | Leading a Deployment Engagement | 18, 19, 20, 21 |
| M2 | Architecture Overview | 1, 2 |
| M3 | Networking Considerations | 10 |
| M4 | User Identity and Provisioning | 3, 4 |
| M5 | Security Considerations | 7, 8, 9 |
| M6 | Data Stores and Actions | 5, 6 |
| M7 | Configurations and Customizations | 11 |
| M8 | Observability | 12, 13 |
| M9 | Adding Agents to Gemini Enterprise | 14, 15 |

Steps 16 and 17 are cross-cutting: a validation checklist across every
technical module, and a set of in-class demo prompts (including a Model
Armor false-positive example that mirrors a real bug documented in
`gcp-cxas-scrapi`'s history — always pair a guardrail's positive trigger
examples with an explicit do-not-flag list).

**M0 (Course Introduction) is not represented anywhere in this script.** It's
NDA terms, session etiquette, the Qwiklabs/Google Skills platform, and the
partner certification program — logistics, not something to automate against
Google Cloud. M1 is mostly organizational/change-management content too
(sponsorship, communications, risk registers), but four of its artifacts are
genuinely automatable and are covered in steps 18-21: a scoping
questionnaire generator, a Day-1 organizational readiness check, a use-case
prioritization rubric, and an engagement cheat sheet. Steps 18-21 mutate
nothing except step 19's read-only `describe`/`list` checks — the rest are
local file generation, which matches the fact that M1's subject matter is
people and process, not infrastructure.

## Why some steps only print instructions

A few pieces of Gemini Enterprise configuration have no stable public API at
the time of writing and are console-only in this script:

- Identity Provider confirmation and the OAuth consent screen / Web-app OAuth
  client (step 6) — confirmed against a live project, per
  `gcp-gemini-cymbalpools`'s own testing notes.
- The Calendar/Gmail/Drive data-connector OAuth handshake (step 6) —
  `setUpDataConnector` has no OAuth-client field.
- Homepage UI, autocomplete, search control, assistant instructions,
  knowledge graph, and feature management (step 11) — all configured under
  **Configurations** in the console.
- Observability toggles (step 12) — enabled under **Configurations >
  Observability**; this script drives Cloud Logging/Monitoring queries
  against the result, but does not flip the toggles themselves.

Anything that does call a Discovery Engine `v1alpha` endpoint (custom MCP
data stores, CMEK config, agent registration, authorizations) is marked
inline with a warning that the field shapes are still evolving — verify
against the console if a call fails.

## A note on organization-level steps

Three steps mutate **organization-level** state rather than just the current
project: Workforce Identity Federation pool/provider creation (step 3),
organization policy constraints (step 8), and VPC Service Controls access
policy/perimeter (step 10). Because a training org is typically shared
across many trainees' sandbox projects, these three steps ask for one
additional typed `YES` confirmation in Create and Delete mode, on top of the
usual option-0 guardrail — this is a deliberate deviation from the
single-confirmation convention used elsewhere in this directory, because
these three specifically can affect other people's projects in the same org
if run against the wrong one. Read the on-screen warning before confirming.

## Prerequisites

- A Google Cloud project with billing enabled, inside an organization (some
  steps require `$ORG_ID` — see above).
- `gcloud` CLI authenticated as a project Owner or Editor, and (for steps 3,
  8, 10) org-level `roles/iam.workforcePoolAdmin`, `roles/orgpolicy.policyAdmin`,
  and `roles/accesscontextmanager.policyAdmin` respectively.
- `python3`/`pip` available for step 14 (ADK install).
- `pv` is installed automatically by the splash screen the first time the
  script runs.

**Confirmed live in a Qwiklabs sandbox: the org-level roles above are not
available there.** A Qwiklabs student account (`student-NN-xxxxx@qwiklabs.net`)
is scoped to the project, not the organization, and `iam.workforcePools.create`
was denied with `IAM_PERMISSION_DENIED` when tested. Steps 3, 8, and 10 can
only be demonstrated in preview mode inside Qwiklabs — actually creating
these resources needs a Google Cloud org you or your training organization
administers.

## Quick start

```bash
cd /path/where/you/want/working/files
./gcp-ge-deploy.sh
```

A menu appears that loops until you press `Q`. **Always start each session
by pressing `0`** to choose an execution mode and confirm the GCP project.

## Execution modes (option `0`)

| Reply | Mode | Behavior |
|-------|------|----------|
| `y` (default) | **Preview** | Prints commands/instructions without running them. |
| `n` | **Create** | Authenticates and executes each step, pausing for manual console work where noted. |
| `d` | **Delete** | Best-effort teardown of what each step created. |

## Configuration (`.env`)

Created at `./gcp-ge-deploy/.env` the first time you run the script. Edit
values before running the numbered steps if you want non-default names.

| Variable | Default | Purpose |
|----------|---------|---------|
| `GCP_PROJECT` | current `gcloud config` project | Target project |
| `GCP_REGION` | `us-central1` | Region for VPC/KMS/ADK resources |
| `GE_LOCATION` | `us` | Gemini Enterprise app/data-store location (never `global` — see step 4 notes in M2/M6 grounding) |
| `APP_NAME` / `APP_ID` | `Gemini Enterprise Deploy Demo` / `ge-deploy-demo` | The app created in step 2 |
| `COMPANY_NAME` | `Your Company` | Shown in the app's common config |
| `GCS_CONTENT_BUCKET` | `<project>-ge-deploy-content` | Sample content bucket for step 5 |
| `WIF_POOL_ID` / `WIF_PROVIDER_ID` | `ge-deploy-wif-pool` / `ge-deploy-oidc` | Step 3 |
| `WIF_ISSUER_URI` / `WIF_CLIENT_ID` | `NOT_SET` | Your IdP's OIDC issuer/client — prompted for in step 3 |
| `WIF_CLIENT_SECRET` | `NOT_SET` | Optional, prompted for in step 3; captured for a future confidential-client flow but not currently passed to `create-oidc` |
| `MCP_SERVER_URL` | `NOT_SET` | HTTPS URL of an MCP server to register — prompted for in step 5 |
| `OAUTH_CLIENT_ID` / `OAUTH_CLIENT_SECRET` | `NOT_SET` | Captured in step 6 |
| `MA_TEMPLATE_ID` | `ge-deploy-template` | Step 7 |
| `KMS_KEYRING` / `KMS_KEY` | `ge-deploy-keyring` / `ge-deploy-cmek-key` | Step 9 |
| `VPC_NAME` / `SUBNET_NAME` / `PSC_ENDPOINT_NAME` | `ge-deploy-vpc` / `ge-deploy-subnet` / `ge-deploy-psc-ep` | Step 10 |
| `AGENT_DIR` | `adk_agent` | Local ADK agent source, scaffolded in step 14 |
| `MODEL` | `gemini-2.5-flash` | Model the demo ADK agent uses |
| `REASONING_ENGINE` | `NOT_SET` | Captured from `adk deploy` output in step 14, consumed by step 15 |
| `AUTH_ID` | `ge-deploy-auth` | Authorization resource name for step 15 |
| `CUSTOMER_NAME` | `Sample Customer` | Prospect/customer name used in step 18's questionnaire |

`.env` is also backed up to `gs://<GCP_PROJECT>/gcp-ge-deploy.sh.env`.

## Menu walkthrough

Run options `1` through `15` once, roughly in order, to stand up a working
demo. Steps within a module (e.g. 7-9 for M5) are independent of each other
but do assume steps 1-2 have already run. Steps 18-21 (M1) are independent
of the technical steps and closer to a facilitator's discovery toolkit than
a deployment sequence — 18, 20, and 21 work in preview mode (`MODE=1`, the
default) without needing option `0` first, though step 19's readiness check
needs option `0` run first so `$ORG_ID`, `$GCP_PROJECT`, and `$IAM_PRINCIPAL`
are populated.

### `(1) [M2] Enable APIs & grant baseline IAM roles`
Enables `discoveryengine.googleapis.com` (the API underlying Gemini
Enterprise, per M2) plus the supporting APIs every later step needs
(`aiplatform`, `iam`, `cloudkms`, `orgpolicy`, `accesscontextmanager`,
`modelarmor`, `logging`, `monitoring`, `cloudtrace`, `storage`, `compute`),
and grants the trainer account baseline Discovery Engine IAM roles. Delete
mode intentionally leaves APIs enabled — other labs in the same project may
depend on them.

### `(2) [M2] Create the Gemini Enterprise app`
Calls `engines.create` to stand up the app every later step attaches a data
store, agent, or policy to — this is the "Search and Agentic Experience"
engine from the M2 architecture diagram. Prints the console URL
(`https://console.cloud.google.com/gemini-enterprise/apps?project=<GCP_PROJECT>`)
and a reminder that the Apps page defaults to **Current location: global**
and will say "There are no apps yet" even though the app exists — click
**Edit** next to Current location and switch it to `$GE_LOCATION` (`us` by
default). Step 5 prints the same reminder for the Data stores page, which
has identical behavior.

### `(3) [M4] Configure Workforce Identity Federation`
Creates a workforce pool and OIDC provider for the syncless, third-party-only
identity path M4 covers. **Organization-level — extra confirmation
required.** If `WIF_ISSUER_URI`/`WIF_CLIENT_ID` aren't already in `.env`,
prints a full walkthrough for standing up a free Okta developer account and
OIDC app first — including which signup tier to pick, the exact sign-in
redirect URI (built from `WIF_POOL_ID`/`WIF_PROVIDER_ID`), the Issuer URI
format, and the groups-claim configuration the script's attribute mapping
depends on — before prompting for the Client ID/Issuer URI/Client Secret.

The signup-tier choice, app creation (OIDC/Web Application, Authorization
Code + Implicit grant, redirect URI), Issuer selection, groups-claim setup,
and where to find the three final values (steps 1-6 and 8 of the
walkthrough) have been live-verified against a real Okta Integrator Free
Plan org and corrected three times from what generic Okta documentation
suggested: that org type hides the classic "Groups claim type" filter
behind a "Show legacy configuration" toggle rather than showing it inline;
the ID token Issuer has no `/oauth2/default` suffix for a Web App
integration; and the Issuer URI is on the **Sign On** tab (OpenID Connect ID
Token section), not the General tab — only Client ID and Client Secret are
on General, under Client Credentials. Test-user creation and assignment
(step 7) is standard Okta UI and believed correct but hasn't been
screenshot-confirmed the way the rest of this walkthrough was.

### `(4) [M4] Grant Gemini Enterprise IAM roles`
Grants `roles/discoveryengine.admin` and `roles/discoveryengine.viewer` at
the project level, with a reminder that app-level roles (for end users)
should be preferred over project-level grants, since project-level IAM
always overrides app-level policy.

### `(5) [M6] Create data stores (Cloud Storage + Custom MCP Server)`
Creates a Cloud Storage data store using **one-time ingestion** (the only
mode that supports ACLs, per M6). The imported content is intentionally
minimal — a single placeholder text file the script writes into a bucket it
just created — enough to prove the create → import → queryable pipeline
works, not a realistic corpus; drop real files into the bucket yourself for
a more substantial demo. Then optionally registers a Custom MCP Server data
store against a URL you provide — there's no bundled MCP server to point
at, since that data store type represents a *customer's own* internal
system exposed as a remote HTTPS MCP server. Pressing Enter to skip that
part is expected; the org-policy override in step 8 already demonstrates
the part of this that matters for training regardless of whether a real
server exists.

### `(6) [M6] Configure OAuth consent & connect actions`
Console walkthrough for the OAuth consent screen, Web-app OAuth client, and
the Calendar/Gmail data-connector wizard — no stable API exists for this
flow. Captures the resulting client ID/secret into `.env`.

### `(7) [M5] Create a Model Armor template & floor setting`
Creates a Model Armor template (content safety filters, prompt
injection/jailbreak detection, sensitive data protection) and a project-level
floor setting. Reminds trainers of the M5 best practice: disable
injection/jailbreak detection on the *response* template specifically.

### `(8) [M5] Set organization policy constraints`
Overrides the constraints that block custom MCP data stores by default
(`discoveryengine.managed.allowedDataSources`,
`discoveryengine.managed.disableCustomMcpServerConnector`) — a prerequisite
for step 5's MCP data store — and writes (without applying) an example
custom constraint that blocks `PUBLIC_WEBSITE` grounding. **Organization-level
— extra confirmation required.**

### `(9) [M5] Configure CMEK for Gemini Enterprise`
Creates a Cloud KMS keyring/key, grants the Discovery Engine service agent
encrypt/decrypt access, and calls the CMEK config endpoint. Delete mode
deliberately does **not** destroy the key — doing so would make encrypted
data permanently unreadable.

### `(10) [M3] Harden networking (timeouts, VPC-SC, PSC)`
Shows the backend-timeout override pattern for agentic latency, optionally
creates a VPC Service Controls access policy and perimeter, and creates a
VPC + Private Service Connect endpoint for internal-IP-only access. **The
VPC-SC portion is organization-level and extra-confirmation-gated** — it can
also affect other projects sharing the org's access policy, so read the
warning carefully before confirming in a shared training org.

### `(11) [M7] Configure homepage UI & hosted web app`
Console walkthrough for branding, autocomplete, and assistant instructions,
then enables the hosted web app and prints its URL.

### `(12) [M8] Enable observability & view metrics`
Console walkthrough for the two Observability toggles (OpenTelemetry
traces/logs; prompt/response logging — PII risk, restrict access), then
queries recent Discovery Engine audit log entries and the Core Assistant's
session-count metric.

### `(13) [M8] Create a log-based alert & inspect traces`
Recreates the exact example from the M8 deck: a log-based metric and
alerting policy that fire when a new data store is created. Points to Trace
Explorer for per-request latency/token debugging.

### `(14) [M9] Deploy a custom ADK agent`
Installs the ADK, scaffolds a minimal agent under `$PROJDIR/$AGENT_DIR`, and
runs `adk deploy agent_engine`, capturing the resulting reasoning-engine
resource name into `.env`.

### `(15) [M9] Register the ADK agent in Gemini Enterprise`
Registers any OAuth client the agent's tools need (`authorizations.create`)
and registers the deployed agent into the app
(`assistants.agents.create`) so it appears in the Agent Gallery. Requires
step 14 to have run first.

### `(16) Validate the full deployment`
Runs a read-only checklist across all eight modules — engine, IAM bindings,
data stores, Model Armor templates, org policy overrides, CMEK config,
recent audit activity, and the reasoning engine — reporting what's missing
so a trainer can quickly see which steps still need to run.

### `(17) Show in-class demo prompts`
Cue-card prompts to run live against the deployed app/agent: an enterprise
grounding query, a Model Armor sensitive-data test, a prompt-injection test,
and a deliberate false-positive check (an ordinary meeting time/ticket
number that should **not** be blocked).

### `(18) [M1] Generate a project scoping questionnaire`
Writes a Customer Response / Notes markdown template covering data strategy,
security controls, compliance regimes, and expected capabilities — the
"foundational document" M1 opens engagement planning with. Prompts for a
customer name and saves it to `.env` for reuse.

### `(19) [M1] Run a Day-1 organizational readiness check`
Read-only checks against two of the four roles M1 says must be engaged
simultaneously in week 1 (org/domain alignment and billing setup are
console-verified; this automates what's checkable via API: org visibility,
billing linkage, the trainer's own org-level IAM roles, and any existing
Workforce Identity Federation pools). Nothing is created or modified.

### `(20) [M1] Score & prioritize use cases (Innovation Matrix rubric)`
Interactively scores candidate use cases 1-5 across Impact, Feasibility,
Priority, Team Readiness, and Project Size — the exact rubric M1 uses to
remove subjectivity from picking where an engagement starts — and prints a
ranked table. Run it multiple times to build up a use-case backlog across a
session.

### `(21) [M1] Show the engagement playbook (phases, stakeholders, risks)`
A pure reference cheat sheet: the 4-phase rollout (Core IT → Early Adopters
→ Global Go-Live → Agentic Follow-Up), the stakeholder map (Executive
Sponsor down to Security & Networking), the five key takeaways for a
successful engagement, the nine Day-1 capabilities worth demonstrating, and
an abridged risk register with mitigations. Useful to have on screen during
a live discovery call.

### `(R)` / `(G)` / `(Q)`
- `R` — show maintainer credits.
- `G` — launch a bundled Cloud Shell tutorial, if `.tutorial.md` exists next
  to the script (not included by default).
- `Q` — quit.

## Working files

```
./gcp-ge-deploy/
├── .env                              # current configuration
├── sample-doc.txt                    # sample content for the M6 data store
├── engine_create.json                # step 2 response
├── gcs_datastore_create.json         # step 5 response
├── gcs_import.json                   # step 5 response
├── mcp_datastore_create.json         # step 5 response
├── allowed_data_sources_policy.yaml  # step 8
├── custom_mcp_policy.yaml            # step 8
├── block-public-website-constraint.yaml  # step 8 (reference only, not applied)
├── floor-settings.yaml               # step 7
├── cmek_config_create.json           # step 9 response
├── alert-policy.yaml                 # step 13
├── adk_agent/                        # step 14 ADK agent source
├── adk_deploy.log                    # step 14 deploy output
├── authorization_create.json         # step 15 response
├── agent_create.json                 # step 15 response
├── scoping_questionnaire.md          # step 18
└── use_case_rubric.csv               # step 20
```

`.env` is also backed up to `gs://<GCP_PROJECT>/gcp-ge-deploy.sh.env`.

## Cleanup

Run in delete mode (`0` → `d`), roughly in reverse order:

1. `15`, `14` — deregister and delete the ADK agent.
2. `13`, `12` — remove the alert policy and log-based metric.
3. `11` — disable the hosted web app (console only).
4. `10` — delete the PSC endpoint/VPC and, if confirmed, the VPC-SC perimeter.
5. `9` — leaves the CMEK key in place by design; destroy it manually once
   nothing depends on it.
6. `8` — reset organization policy constraints to their inherited default.
7. `7` — delete the Model Armor template.
8. `6` — delete the OAuth client and data connector (console only).
9. `5` — delete the data stores and content bucket.
10. `4`, `3` — remove IAM bindings and, if confirmed, the WIF pool/provider.
11. `2` — delete the Gemini Enterprise app.
12. `1` — leaves APIs enabled by design; other labs in this project may need them.
13. `18`, `20` — delete the generated questionnaire and use-case rubric
    (step 19 and 21 create nothing, so there's nothing to remove).
14. Delete the `./gcp-ge-deploy/` working directory.
