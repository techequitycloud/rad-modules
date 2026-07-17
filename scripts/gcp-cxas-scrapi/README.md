# gcp-cxas-scrapi.sh — CXAS SCRAPI Cymbal Pools Demo

Interactive bash script that walks a trainer through the full breadth of
**CXAS SCRAPI** (`github.com/GoogleCloudPlatform/cxas-scrapi`), the Python
library and `cxas` CLI that wraps **CX Agent Studio** (console at
[ces.cloud.google.com](https://ces.cloud.google.com/)) — Google's
instruction/LLM-driven successor to flow-based Dialogflow CX. The demo builds
a **Cymbal Pools** scheduling agent from scratch: instructions, tools, a
slot-filling callback, a guardrail, evaluations, CI/CD, branching, a
multi-agent split, "vibe coding" via the Antigravity CLI, a PRD-driven
agent-foundry build, and a voice variant. It follows the same
menu/preview/create/delete pattern as the other scripts in this directory
(see `../gcp-gemini-cymbalpools/README.md` for the shared conventions).

## Validated against a live project

Unlike the console-only products covered by other scripts here, `cxas` is a
real pip package with a stable, documented CLI. Steps `1`–`13` and `17` were
exercised end-to-end against a real GCP project and CX Agent Studio app
(`cxas create` → `pull` → `local create agent/tool/guardrail` → author →
`lint` → `push` → `test-tools`), which surfaced several real discrepancies
from the public docs that are now fixed here:

- **The instructions file is `instruction.txt` (singular)**, not
  `instructions.txt`.
- **There is no `cxas local create callback`** — only `agent`, `tool`, and
  `guardrail` have local templates. Callbacks are hand-created directly
  under the owning agent at `agents/<agent>/before_model_callbacks/<name>/
  python_code.py`, with the real signature `before_model_callback
  (callback_context: CallbackContext, llm_request: LlmRequest) ->
  Optional[LlmResponse]` and wired onto the agent's JSON as an **object**
  (`{"pythonCode": ..., "description": ..., "disabled": false}`), not a bare
  string.
- **`app.json` requires a `rootAgent` field**, and lint rule `A005` requires
  the root agent's `tools` list to include the built-in `end_session` tool
  (referenced by name only — it needs no local scaffolding).
- **Guardrails are directories** (`guardrails/<name>/<name>.json` with
  `llmPolicy.prompt` and `action.generativeAnswer.prompt` fields), scaffolded
  via `cxas local create guardrail`, not flat YAML files.
- **Multi-agent routing uses the `child_agents` field**, not `subAgents`.
- **`cxas branch` has no custom-app-id flag** — it always assigns a random
  UUID, so this script captures the resulting ID from `cxas apps list`
  afterward rather than predetermining it (step `19`'s voice variant sidesteps
  this entirely by using `cxas create` + a local copy instead of branching).
- Real tool-test response paths are nested under `$.result.<field>`
  (`cxas test-tools --debug` shows the exact wrapping), and several CLI flags
  differ from the docs' prose (`cxas create --project-id`, not `--project`;
  `cxas delete --app-name ... --force`, not a positional arg + `--quiet`;
  `cxas push-eval --file`, not `--eval-file`; `cxas ci-test`/`local-test`
  require `--project-id`/`--location`; `cxas insights list-scorecards`, not
  `list`; `cxas trace list`/`cxas trace open`, not a bare `cxas trace`).
- **The golden-eval YAML is "Dataset format"**: a top-level `conversations:`
  list where each item's `conversation:` field is the eval's **display
  name** (a string, not the turn list), and `turns:` holds `{user, agent,
  tool_calls: [{action, args}]}` objects — the `expect_tool_call`/
  `expect_response_contains` shorthand this script originally guessed
  doesn't exist. `cxas test-callbacks`'s callback test is a plain pytest
  `test.py` colocated with `python_code.py` (from step 6), importing and
  calling `before_model_callback` directly against a small fake context.
- **`cxas run` has no "run everything" bare invocation** — it requires
  `--evaluation-id`, `--display-name-prefix`, or `--tags` to select which
  tests to run. `load_golden_evals_from_yaml` auto-tags every pushed golden
  with its YAML file's basename, so `--tags happy_path` would also work.
- **The guardrail's original prompt false-triggered** on ordinary
  conversational content (a time like "11:30") and silently ate the
  booking turn, which is why the golden failed with `Actual: (None /
  Missed)` for `book_appointment` — the guardrail's canned refusal was
  returned instead of the model ever getting to call the tool. Diagnosed
  via `cxas trace list --source EVAL --format json` to find the eval's
  conversation ID, then `cxas trace get <id> --format text` to see the
  turn-by-turn transcript including which step (`Guardrail`, `Callback`,
  `LLM`) fired — that's the general technique for debugging *any* eval
  failure that isn't self-explanatory from `cxas run`'s summary. Fixed by
  rewriting the prompt with an explicit "DO NOT FLAG" section (the
  platform's own auto-generated guardrail template has one for exactly
  this reason, which the original prompt skipped) and requiring an actual
  13-19-digit card-like sequence rather than "contains digits."

**Still best-effort / not live-verified** — flagged inline with the exact
`--help` command to check if it fails:

- Whether the scheduler also needs a `transfer_rules` entry (step `13`) to
  actually route to the FAQ agent live, beyond `child_agents`.
- `cxas insights` and the agent-foundry PRD skill (step `18`, which also
  needs an interactive `agy` OAuth session) were not run to completion
  live. (`cxas ci-test` and `cxas local-test` *were* — see step `11` above.)

Treat this script as a strong, mostly-verified starting point — rerun it
against a real project before using it live in front of a class.

Steps **14–16 and 18** deliberately hand control to the interactive
**Antigravity CLI** (`agy`) — CXAS SCRAPI's own "vibe coding" workflow. The
script prints the exact natural-language prompt to paste in, then pauses for
you to complete the conversation and exit back to the script. This mirrors
GENAI176/GENAI177 exactly rather than hand-authoring everything
deterministically.

## Prerequisites

- Google Cloud project with billing enabled; `aiplatform`, `dialogflow`,
  `cloudbuild`, `run`, `bigquery`, `storage`, `cloudtrace`, and `logging` APIs
  available.
- `gcloud` CLI authenticated as a project Owner or Editor.
- Internet egress to install `uv`, `cxas-scrapi` (PyPI), and the Antigravity
  CLI installer.
- (Optional) Docker, for step 11's `cxas local-test`.

## Quick start

```bash
cd /path/where/you/want/working/files
./gcp-cxas-scrapi.sh
```

A menu appears that loops until you press `Q`. **Always start each session by
pressing `0`** to choose an execution mode and confirm the GCP project.

## Execution modes (option `0`)

| Reply | Mode | Behavior |
|-------|------|----------|
| `y` (default) | **Preview** | Prints commands/instructions without running them. |
| `n` | **Create** | Authenticates and executes each step, pausing for manual console/`agy` work. |
| `d` | **Delete** | Best-effort teardown of what each step created. |

In Create / Delete mode the script runs both `gcloud auth login` (the
`gcloud` CLI's own identity) **and** `gcloud auth application-default login`
(Application Default Credentials, ADC) for the same account, then sets that
account as the ADC quota project and creates a `gs://<project>` bucket for
backing up `.env`. Both matter: `cxas` itself authenticates via ADC, not
whatever account `gcloud` CLI commands are using — confirmed by testing, the
two are genuinely separate credential stores, and a shell where only
`gcloud auth login` has run will fail `cxas push`/`cxas create` with a
confusing `ces.apps.import` permission error, because `cxas` falls back to
ambient credentials (on Cloud Shell, the VM's own service account, which has
none of the granted roles). If you are already authenticated as the right
principal (e.g. a Qwiklabs student account with the roles from step 1
pre-granted) via both mechanisms, you can skip option `0`'s `n`/`d` flow
entirely and just export `GCP_PROJECT` yourself before running the numbered
steps.

**Why not a service-account key?** An earlier version of this script created
a dedicated service account with `roles/owner` and pointed
`GOOGLE_APPLICATION_CREDENTIALS` at its key file, matching the convention
other scripts in this directory use for Terraform-heavy provisioning. For
`cxas` specifically that turned out to be strictly worse: it's a second,
more fragile credential system layered on top of ADC (which already works,
since the pre-granted roles belong to your own account), and in practice hit
a repeating class of failures — a key file invalidated by a later
delete/recreate of the service account, an empty/corrupt key file from an
IAM-propagation race right after creating the account, and a `GOOGLE_
APPLICATION_CREDENTIALS` `export` that doesn't survive a new terminal.
Plain ADC for your own account persists reliably on disk
(`~/.config/gcloud/application_default_credentials.json`) across new
terminals and Cloud Shell reconnects with no extra bookkeeping, so the
script no longer creates a service account at all. Step 2 still appends a
one-time auto-activation block to `~/.bashrc` (source the venv and `.env`)
so `cxas` and `$GCP_PROJECT`/etc. are available in any new shell without
re-running option `0` — auth itself doesn't need it.

## Configuration (`.env`)

Created at `./gcp-cxas-scrapi/.env`. Edit values before running the numbered
steps:

| Variable | Default | Purpose |
|----------|---------|---------|
| `GCP_PROJECT` | current `gcloud` project | Target project ID. |
| `CXAS_LOCATION` | `us` | Location used consistently across every app/agent/branch. |
| `GCS_BUCKET` | `<project>-cxas` | Bucket for eval-report backups. |
| `APP_NAME` / `APP_ID` / `APP_DIR` | `Cymbal Pools Service` / `cymbal-pools-service` / `Cymbal_Pools_Service` | The primary scheduling app. `APP_DIR` matches `cxas pull`'s own space→underscore display-name transform. |
| `MODEL` | `gemini-3-flash` | Text-modality model for the primary app. |
| `AGENT_NAME` | `scheduler` | Root agent name. |
| `FAQ_AGENT_NAME` | `faq` | Child agent created in step 13. |
| `GUARDRAIL_NAME` | `no_payment_info` | Guardrail created in step 9. |
| `BRANCH_APP_NAME` / `BRANCH_APP_DIR` | `Cymbal Pools Service Branch` / `Cymbal_Pools_Service_Branch` | Safety-net branch used by steps 13–18. |
| `BRANCH_APP_ID` | `NOT_SET` | Captured by step 12 from `cxas apps list` — `cxas branch` assigns a random UUID, so this can't be predetermined. |
| `FOUNDRY_APP_NAME` / `FOUNDRY_APP_ID` / `FOUNDRY_APP_DIR` | `Cymbal Pools Membership` / `cymbal-pools-membership` / `Cymbal_Pools_Membership` | Second app built by the agent-foundry skill in step 18 (`cxas create` supports a custom app-id). |
| `VOICE_APP_NAME` / `VOICE_APP_ID` / `VOICE_APP_DIR` | `Cymbal Pools Service Voice` / `cymbal-pools-service-voice` / `Cymbal_Pools_Service_Voice` | Voice-modality variant created in step 19. |
| `VOICE_MODEL` | `gemini-3.1-flash-live` | Audio-modality model for the voice variant. |
| `IAM_PRINCIPAL` | `NOT_SET` | Captured by step 1 (`gcloud config list account`). |

## Menu walkthrough

Run options `1` → `10` once, in order, to stand up and validate the baseline
scheduler agent. From `11` onward the demo branches off to show CI/CD,
architecture, AI-assisted authoring, and multimodal capabilities without
touching that tested baseline.

### `(1) Enable APIs & grant IAM roles`
Enables `aiplatform`, `dialogflow`, `cloudbuild`, `run`, `bigquery`,
`storage`, `cloudtrace`, and `logging`, then grants the current principal
`roles/aiplatform.user`, `roles/dialogflow.admin`, `roles/storage.objectAdmin`,
`roles/bigquery.dataViewer`, `roles/bigquery.dataEditor`,
`roles/logging.viewer`, and `roles/cloudtrace.user`. Delete mode removes the
role bindings but leaves APIs enabled, per this repo's API-enablement
convention.

### `(2) Install CXAS SCRAPI`
Installs `uv` if missing, creates `.venv`, installs `cxas-scrapi` from PyPI,
verifies with `cxas --help`, and creates a bucket for eval-report backups.

### `(3) Create the app & pull it locally`
`cxas create --project-id ... --location ...` registers the app in CX Agent
Studio; `cxas pull ... --target-dir $PROJDIR` brings it down to
`$PROJDIR/$APP_DIR` (the directory name is `cxas pull`'s own display-name
transform, not something you can pass directly). Writes `gecx-config.json`
(the real CXAS SCRAPI project config format) so later steps don't need `--to`
on every command.

### `(4) Scaffold the agent & author instructions`
`mkdir -p agents` (required — `cxas local create agent` fails if it doesn't
already exist), then `cxas local create agent` scaffolds `agents/scheduler/`.
The script writes `instruction.txt` directly using the role/persona/
constraints/taskflow XML pattern from the Instruction Design guide, including
a `${current_date}` reference (avoids an `I014` lint warning) and a
termination subtask calling the built-in `end_session` tool.

### `(5) Author the scheduling tools`
Scaffolds `check_availability` and `book_appointment` via `cxas local create
tool ... python --add-to-agent`, then writes each `python_code.py` with the
official `agent_action` error-return convention (Tool Design guide).

### `(6) Add a slot-filling callback`
`cxas` has no local-create template for callbacks, so this hand-creates
`agents/scheduler/before_model_callbacks/state_orchestrator/python_code.py`
with the real `before_model_callback(callback_context, llm_request)`
signature, plus a colocated `test.py` for step 10/`cxas test-callbacks`, and
wires it onto `scheduler.json`'s `before_model_callbacks` list as an object
(not a bare string). Implements a self-healing branch that clears a failed
slot instead of repeating the same failed call forever (Callbacks guide;
Slot Filling and Self-Healing patterns).

### `(7) Lint and push the agent`
Wires `rootAgent` in `app.json` and adds the built-in `end_session` tool to
the root agent (both required by `cxas lint`), runs structural `cxas lint`
and semantic `cxas llm-lint --agent-dir agents/scheduler`, then
`cxas push --app-dir . --to ...`.

### `(8) Preview & manually test the agent`
Manual by design. Prints the baseline conversation to run in the console's
Preview Agent and pauses for confirmation.

### `(9) Author a guardrail`
`cxas local create guardrail` scaffolds `guardrails/no_payment_info/
no_payment_info.json`; the script fills in the generated `llmPolicy.prompt`
(trigger criteria) and `action.generativeAnswer.prompt` (the refusal
response) — both required fields — then pushes it and pauses to test the
refusal in Preview (Guardrails guide).

### `(10) Write goldens, tool tests & callback tests`
Writes a golden conversation using the real "Dataset format" schema
(`conversations: [{conversation: <display name>, turns: [{user, agent,
tool_calls}]}]`) and two tool tests (`tests: - name/tool/args/
expectations.response[].{path,operator,value}`, with response paths nested
under `$.result.<field>`), then runs `cxas test-tools` (×2),
`cxas test-callbacks --app-dir . --agent-name scheduler --callback-name
state_orchestrator` (runs step 6's `test.py`), `cxas push-eval --file`, and
`cxas run --display-name-prefix happy_path --wait` (`cxas run` has no
"run everything" mode — it requires an explicit filter) (Testing &
Evaluation guide).

### `(11) Run CI/CD tests`
Runs `cxas ci-test` with a fixed `--display-name "[CI] gcp-cxas-scrapi"` —
confirmed by testing, `ci-test` always pushes to a **new** temp app and
never deletes it ("Temp agent persists for review" is deliberate), so a
fixed display name makes repeat runs update the same temp app instead of
accumulating orphans; delete mode removes it by that display name. If
Docker is available, writes `Dockerfile`/`requirements.txt` directly before
running `cxas local-test` (both require `--project-id --location`) —
confirmed by testing, `cxas init-github-action` normally generates these as
a side effect, but only *after* its WIF check passes (see below), so
`local-test` has nothing to build against unless that already succeeded.
The written Dockerfile also swaps the generated template's `COPY .../uv
/uvbin --link` + `PATH` trick for the standard `COPY .../uv
/usr/local/bin/uv`, since `--link` hit a BuildKit-version-dependent
checksum bug in testing. It also extracts `ces-v1beta-py.tar` with system
`tar` before installing from the resulting directory, instead of letting
`uv pip install` parse the `.tar` directly — confirmed by testing, `uv`'s
own tar parser fails on this specific archive (`numeric field did not have
utf-8 text ... when getting cksum`), a bug in `uv`'s tar handling rather
than the archive itself; system `tar` extracts it without complaint. With
all three fixes the full build succeeds end-to-end (verified live).
Runs `cxas init-github-action --app-name ...` explicitly —
confirmed by testing, it looks for an `app.yaml` (we have `app.json`) and
silently synthesizes the *wrong* app-id from the directory name if
`--app-name` is omitted. Even with the correct app-name, it still requires
`--workload-identity-provider`/`--service-account` or `--auto-create-wif`
(which provisions real Workload Identity infrastructure) to produce a
working workflow — this script only scaffolds the template and leaves that
choice to you rather than silently creating persistent GCP resources.

### `(12) Branch the app for experiments`
`cxas branch <source> --new-name ... --project-id ... --location ...`
pulls → creates → pushes a **new app with an auto-generated UUID app-id** —
there is no flag to set a custom one. The script looks up the resulting ID
via `cxas apps list` (matching on display name) and saves it to `.env` as
`BRANCH_APP_ID`, then pulls it to `$PROJDIR/$BRANCH_APP_DIR`. Steps `13`–`19`
all operate on this branch so the validated baseline from steps `3`–`10` is
never touched by the AI-driven or architectural experiments that follow.

### `(13) Split off a second agent (multi-agent architecture)`
On the branch, scaffolds a `faq` agent (with its own `<taskflow>` — every
agent's instructions need one, root or not, confirmed by lint rule `I001`)
and adds it to `scheduler.json`'s `child_agents` list (Agent Architecture
guide: start single-agent, split only once a second, genuinely distinct
responsibility appears). Whether live routing also needs a `transfer_rules`
entry was not confirmed — check the console's agent transfer settings if
the FAQ agent doesn't trigger in Preview.

`cxas lint` at this point may report `[V005]` on a guardrail named something
like `Safety_Guardrail_<timestamp>` or `Prompt_Guardrail_<timestamp>` —
confirmed by testing, those are the platform's own built-in guardrails
(Safety / Prompt Guard, visible as toggles in the console's Guardrails
panel), using `modelSafety`/`llmPromptSecurity` rather than `llmPolicy` and
genuinely having no `prompt` field. That's a lint false positive on
platform-managed guardrails we never created or touched, safe to ignore.

### `(14) Install the Antigravity CLI`
Installs `agy` and runs `cxas init` inside the branch directory to register
the CXAS SCRAPI skills Antigravity uses.

### `(15) Vibe-code: convert tools to use variables`
Prints the exact prompt (from GENAI176's Task 3) to paste into `agy`,
converting the tools to use CX session variables so multiple appointments can
be tracked. Pauses for you to complete the conversation, then lints and
pushes.

### `(16) Vibe-code: golden eval & guardrail refinement`
Prints two prompts (from GENAI177's Tasks 3 and 5): generate a golden from a
pasted conversation, and extend the guardrail to also catch bank/routing
numbers. Pauses, then lints and pushes.

### `(17) Run local simulations`
`cxas evals report --run --app-name ... --output-dir eval-reports
--sim-parallel 5` — runs every golden, tool test, callback test, and Local
Simulation together (the default `--include` is already `sims,goldens,tools,
callbacks`; passing `--include sims` explicitly would *narrow* the report to
sims only, so it's deliberately omitted). Simulations use an AI-powered user
simulator (Gemini) that tries to reach a goal, then Gemini judges whether the
agent met it.

### `(18) Agent-foundry: build an agent from a PRD`
Creates a second app (`Cymbal Pools Membership`) via `cxas create --app-id`
(which, unlike `cxas branch`, does support a custom ID), bundles a short PRD
markdown file, and hands control to `agy` with the `agent-foundry` skill
prompt to build the whole agent from that PRD in one shot. Not run to
completion live — it needs an interactive `agy` OAuth session.

### `(19) Create a voice variant`
`cxas create --app-id` a fresh voice app (branching was considered but
rejected here since `cxas branch` can't take a custom app-id), copies the
tested `$APP_DIR` content locally, edits `gecx-config.json` to `modality:
audio` / `model: gemini-3.1-flash-live`, and pushes — showing CXAS SCRAPI's
multimodal support.

### `(20) Enable Cloud Logging & trace a conversation`
Console-only toggle (Settings > Advanced > Enable Cloud Logging), then
`cxas trace list --app-name ... --limit 5` and `cxas trace open` (prints,
and on macOS opens, the console URL for the app).

### `(21) View Insights quality scorecards`
`cxas insights list-scorecards --parent projects/.../locations/...` (the
docs' `cxas insights list` is not a real subcommand), plus console steps to
review the QA scorecards under the app's Insights tab.

### `(22) Show in-class demo prompts`
Pure cue card — no execution. Prompts spanning the baseline scheduler, the
guardrail, multi-agent FAQ routing, the voice variant, and the agent-foundry
membership agent.

### `(R)` / `(G)` / `(Q)`
- `R` — show maintainer credits.
- `G` — launch a bundled Cloud Shell tutorial, if `.tutorial.md` exists next to
  the script (not included by default).
- `Q` — quit.

## Working files

```
./gcp-cxas-scrapi/
├── .env                              # current configuration
├── .venv/                            # cxas-scrapi virtual environment
├── Cymbal_Pools_Service/             # primary app (steps 3-11)
│   ├── gecx-config.json
│   ├── app.json                      # rootAgent: scheduler
│   ├── agents/scheduler/
│   │   ├── instruction.txt
│   │   ├── scheduler.json            # tools + before_model_callbacks
│   │   └── before_model_callbacks/state_orchestrator/
│   │       ├── python_code.py
│   │       └── test.py
│   ├── tools/check_availability/ , tools/book_appointment/
│   ├── guardrails/no_payment_info/no_payment_info.json
│   └── evals/goldens/ , evals/tool_tests/
├── Cymbal_Pools_Service_Branch/      # experimental branch (steps 13-18)
│   ├── agents/faq/                   # added in step 13
│   └── eval-reports/                 # from step 17
├── Cymbal_Pools_Membership/          # agent-foundry app (step 18)
│   └── prds/cymbal_pools_membership_prd.md
└── Cymbal_Pools_Service_Voice/       # voice variant (step 19)
```

`.env` is also backed up to `gs://<GCP_PROJECT>/gcp-cxas-scrapi.sh.env`.

## Cleanup

1. Option `0` → `d` (delete mode).
2. Run `19`, `18`, `12` in delete mode to remove the voice, agent-foundry, and
   branch apps.
3. Run `11`, `10`, `9`, `7` in delete mode to clean up local CI/eval/guardrail
   artifacts (the primary app's tested content).
4. Run `6`, `5`, `4` in delete mode to remove the local callback, tools, and
   agent, then `3` to delete the primary app itself.
5. Run `2` to remove the virtual environment and eval-report bucket, then `1`
   to remove the IAM bindings (APIs are left enabled).
6. Delete `./gcp-cxas-scrapi/`. The Antigravity CLI (step 14) is left
   installed — it is not project-scoped. ADC (`gcloud auth
   application-default revoke`) is left as-is, since it's your own account's
   credential, not something this script owns.
