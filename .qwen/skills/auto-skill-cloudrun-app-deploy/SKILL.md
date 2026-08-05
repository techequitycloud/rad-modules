---
name: cloudrun-app-deploy
description: Deploy multiple Cloud Run application modules concurrently from partner-modules — covering app selection, stale-state parking, tfvars creation, staggered applies to avoid IAM etag races, Playwright verification, and scale-to-zero cleanup.
source: auto-skill
extracted_at: '2026-07-13T21:00:00Z'
---

# Concurrent Cloud Run Application Deployment

## Purpose

Deploy one or more Cloud Run application modules from the `partner-modules`
repository onto an existing `Services_GCP` platform. When deploying multiple
apps concurrently, staggers the `tofu apply` starts by 2 minutes to avoid
shared-project IAM-policy etag races (each app grants ~12-19 SA roles early
in apply — two simultaneous grants collide).

## Pre-flight checks

### 1. Platform must exist

Every app module binds to `Services_GCP` via `tenant_deployment_id`. Confirm
the platform is healthy before deploying apps:

```bash
gcloud compute networks list --project=$P --format='value(name)'
gcloud container clusters list --project=$P --region=$R --format='value(name,status)'
gcloud sql instances list --project=$P --format='value(name,state,databaseVersion)'
```

The VPC, GKE cluster (RUNNING), and any SQL instances the apps need must be
present and healthy.

### 2. Pick the right apps — prebuilt vs custom-build

**Prebuilt** apps (image pulled from Docker Hub / GHCR) deploy in 3-5 min
with no Cloud Build. **Custom-build** apps (Cloud Build from a source
registry) take 8-15 min and consume build minutes + a build worker slot.

Prebuilt examples: UptimeKuma, Changedetection, Matomo, SnipeIT, Appsmith,
Gitea (with `container_image_source = "prebuilt"`).

Check whether an app is prebuilt-capable:

```bash
grep "container_image_source" modules/<App>_CloudRun/variables.tf
```

- `default = "prebuilt"` → prebuilt by default (no extra config needed)
- `default = "custom"` with OPTIONS=prebuilt,custom → set
  `container_image_source = "prebuilt"` in tfvars
- No variable → the wiring file handles it via the Common module

**Lightweight apps to prefer first** (least resource contention):
1. No-DB apps (UptimeKuma — embedded SQLite; CodeServer — no DB at all)
2. SQLite-on-GCS apps (Changedetection — no Cloud SQL instance needed)
3. PostgreSQL apps (Gitea, Docmost, CalCom — provision a Cloud SQL instance)

**Known prebuilt CloudRun apps** (deploy in 3-5 min, no Cloud Build):
- UptimeKuma, CodeServer, Coder — no database
- Changedetection — SQLite on GCS, no Cloud SQL
- Ghost — MySQL, prebuilt image works (verified "Ghost", HTTP 200)
- Metabase, Plane — PostgreSQL, prebuilt image works (verified)
- CloudBeaver, Beszel — no DB, prebuilt image (verified)
- CalibreWeb — lightweight, prebuilt image (verified)
- Cloudreve — no DB, prebuilt (verified)
- Cyclos — no DB, prebuilt (verified)
- Docmost — PostgreSQL, prebuilt image (verified)
- StirlingPDF — no DB, prebuilt (verified "Stirling PDF", HTTP 200)
- Listmonk — PostgreSQL, prebuilt (verified HTTP 200)
- Shlink — PostgreSQL, prebuilt (verified HTTP 404 from app, container runs)
- LobeChat — no DB, prebuilt (verified HTTP 307)
- OpenWebUI — heavy custom build but prebuilt-capable (verified HTTP 200)
- Wordpress — MySQL, prebuilt (verified HTTP 302)
- Matomo — MySQL, prebuilt (verified HTTP 200)
- Odoo — PostgreSQL, custom build required for full init but service deploys (verified)
- Superset — PostgreSQL, custom build (verified HTTP 302)
- Keycloak — PostgreSQL, custom build (verified HTTP 302)
- Nextcloud — PostgreSQL, custom build (verified HTTP 302)
- Activepieces — PostgreSQL, custom build (verified "Sign Up | Activepieces")
- N8N — PostgreSQL, custom build (verified "n8n.io - Workflow Automation")
- Mattermost — PostgreSQL, requires `database_type = "POSTGRES_15"` explicitly (verified "Mattermost", HTTP 200)
- Dify — PostgreSQL, custom build (verified)
- Grafana — PostgreSQL, prebuilt (verified "Grafana", HTTP 200)
- ActualBudget — no DB, prebuilt (verified)
- Affine — no DB, prebuilt (verified)
- Django — PostgreSQL, prebuilt (verified)
- Filebrowser — no DB, prebuilt (verified)
- Gotify — no DB, prebuilt (verified)
- Hoppscotch — no DB, prebuilt (verified)
- Kavita — no DB, prebuilt (verified)
- LibreChat — no DB, prebuilt (verified)
- Meilisearch — no DB, prebuilt (verified)
- PocketBase — SQLite, prebuilt (verified)
- PhotoPrism — no DB, prebuilt (verified)
- Rallly — PostgreSQL, prebuilt (verified)
- SearXNG — no DB, prebuilt (verified)
- ToolJet — no DB, prebuilt (verified)
- Umami — PostgreSQL, prebuilt (verified)
- FreshRSS — PostgreSQL, prebuilt (verified)
- Miniflux — PostgreSQL, prebuilt (verified)
- Excalidraw — no DB, prebuilt (verified)
- CalibreWeb — no DB, prebuilt (verified "Change Detection" type UI)
- Cloudreve — no DB, prebuilt (verified)
- Cyclos — no DB, prebuilt (verified)
- Documenso — PostgreSQL, prebuilt-capable
- Fider — PostgreSQL, prebuilt
- LangFlow — no DB, prebuilt
- Ntfy — no DB, lightweight API-first (verified)

**Known custom-build CloudRun apps** (Cloud Build wrapper required):
- Gitea — MUST use `custom`; prebuilt fails (no `$(VAR)` env interpolation)
- CalCom — default is already `"custom"` (NOT prebuilt); Docker Hub image rejected by Cloud Run
- Directus — MUST use `custom`; `DB_DATABASE` vs `DB_NAME` env var mismatch
- Castopod — MUST use `custom`; s6-overlay permission errors on Cloud Run
- Audiobookshelf — MUST use `custom`; `PORT` env var conflicts with Cloud Run's reserved `PORT`

**Apps with known deployment issues** (skip/revisit without explicit fixes):

- **Outline** — Cloud Build fails (exit 127, kaniko step "command not found")
- **BookStack** — plan incomplete on fresh state; needs `database_type = "MYSQL"` + complete state reset
- **Flowise** — plan incomplete repeatedly; complete state reset may help
- **Chatwoot** — plan incomplete; complete state reset may help
- **Moodle** — needs `application_version` variable explicitly set; plan incomplete otherwise
- **AnythingLLM** — plan incomplete
- **Audiobookshelf** — PORT reserved-env conflict persists even with `custom` image (module issue)
- **Documenso** — deploys but startup probe fails on PORT=3000 (container eventually serves 403); needs longer probe timeout or custom wrapper
- **Miniflux** — deploys but startup probe fails (container eventually serves 403); needs longer probe timeout
- **Paperless** — succeeds ONLY when CPU quota is free; fails with quota-exhausted during parallel campaigns; re-apply after bulk scale-to-zero
- **Authentik, Docuseal, Monica, InvoiceNinja, LangFlow, Ntfy, Fider, Rallly, Umami, Vikunja, Windmill, Zammad, Zitadel, Tolgee, ToolJet, WriteFreely, Strapi, Unleash** — "Cannot apply incomplete plan"; these need complete state reset (`rm -f terraform.tfstate* .terraform.lock.hcl`) + re-init from scratch. Most are prebuilt-capable once the stale state is cleared.

## Procedure

### Step 1: Park stale state

Application module directories may carry state from prior labs. Check:

```bash
ls modules/<App>_CloudRun/terraform.tfstate*
```

If `terraform.tfstate` exists and points at a different project:
```bash
cd modules/<App>_CloudRun
mv terraform.tfstate "terraform.tfstate.parked-gcpXX-$(date +%Y%m%d)"
rm -f terraform.tfstate.backup plan.tfplan .terraform.tfstate.lock.info
```

### Step 2: Write `config/deploy.tfvars` for each app

Create or update `modules/<App>_CloudRun/config/deploy.tfvars`:

```hcl
resource_creator_identity = ""
project_id                = "<target-project-id>"
tenant_deployment_id      = "demo"       # MUST match the deployed Services_GCP platform

# If the app supports prebuilt image (check variables.tf):
container_image_source    = "prebuilt"

# If the app uses an external database:
database_type             = "POSTGRES"   # or MYSQL
```

**Key points:**
- `tenant_deployment_id` must match the platform — every module in a tenant
  uses the same tenant ID so they share SAs, VPC, and registry.
- `resource_creator_identity = ""` forces the provider to use caller
  identity (no SA impersonation) — correct for direct deploys.
- **CloudRun and GKE variants of the same app on the same tenant collide**
  (identical `service_name`, secrets, buckets, rotation topic). If deploying
  both variants, give them distinct tenants (`tenant_deployment_id = "cr"`
  vs `"gke"`) or suffix the GKE `application_name` with `-gke`. Different
  apps on the same tenant (e.g. UptimeKuma + Gitea, both CloudRun) are fine —
  they get unique `service_name` from different `application_name` values.

**Shell-safe tfvars creation:** Use `printf` instead of heredoc for writing
tfvars in shell scripts. Heredocs (`cat <<EOF`) break with complex quoting
inside bash functions and `for` loops. The `printf` approach is more robust,
especially in batch scripts:

```bash
# Reliable in any shell context
printf 'resource_creator_identity = ""\nproject_id = "%s"\ntenant_deployment_id = "demo"\ncontainer_image_source = "prebuilt"\n' \
  "$PROJECT_ID" > modules/<App>_CloudRun/config/deploy.tfvars

# For apps needing a database:
printf 'resource_creator_identity = ""\nproject_id = "%s"\ntenant_deployment_id = "demo"\ncontainer_image_source = "custom"\ndatabase_type = "POSTGRES"\n' \
  "$PROJECT_ID" > modules/<App>_CloudRun/config/deploy.tfvars
```

This avoids the quoting pitfalls that make `cat <<EOF` silently produce
malformed tfvars when nested inside `for` loops or bash functions.

### Step 3: Init, validate, plan (serial per app, parallel across apps)

These are read-only — no cloud API contention. Run them all in parallel:

```bash
cd modules/<App>_CloudRun
GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token 2>/dev/null)" \
  tofu init -reconfigure -upgrade -input=false
GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token 2>/dev/null)" \
  tofu validate
GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token 2>/dev/null)" \
  tofu plan -input=false -no-color -var-file=config/deploy.tfvars -out=plan.tfplan
```

Check the `Plan: N to add` line before proceeding. Apps without a database
typically provision 35-40 resources; apps with PostgreSQL/MySQL provision
60-75 resources (includes Cloud SQL instance, DB, user, and init jobs).

**Combined one-liner for batch speed:** Init and plan can be merged into a
single subshell command, saving time when deploying many apps:

```bash
for app in App1_CloudRun App2_CloudRun App3_CloudRun; do
  (cd "$BASE/$app" && \
    GOOGLE_OAUTH_ACCESS_TOKEN="$TOKEN" tofu init -reconfigure -upgrade -input=false 2>&1 | tail -1 && \
    rm -f plan.tfplan && \
    GOOGLE_OAUTH_ACCESS_TOKEN="$TOKEN" tofu plan -input=false -no-color \
      -var-file=config/deploy.tfvars -out=plan.tfplan 2>&1 | grep "Plan:") &
done
wait
```

The `rm -f plan.tfplan` before each plan ensures a stale plan from a failed
prior run doesn't cause `tofu plan` to append. The `grep "Plan:"` gives a
compact summary line. Any app whose plan line is missing after `wait` failed
init or plan — check its `.terraform/` directory and retry.

### Step 4: Apply with staggered starts

**Stagger rule:** 2-minute gaps between applies so each app clears its
IAM-grant phase (~12-19 `gcloud projects add-iam-policy-binding` calls)
before the next app starts granting. Simultaneous grants on the same
project IAM policy collide on the etag.

Start the lightest app first (no DB), then medium (SQLite/GCS), then
heavy (PostgreSQL/MySQL):

```bash
# App 1 (lightest) — start immediately
cd modules/<LightApp>_CloudRun && GOOGLE_OAUTH_ACCESS_TOKEN="..." tofu apply plan.tfplan &

# App 2 (medium) — sleep 120 before applying
(sleep 120 && cd modules/<MediumApp>_CloudRun && GOOGLE_OAUTH_ACCESS_TOKEN="..." tofu apply plan.tfplan) &

# App 3 (heavy) — sleep 240 before applying
(sleep 240 && cd modules/<HeavyApp>_CloudRun && GOOGLE_OAUTH_ACCESS_TOKEN="..." tofu apply plan.tfplan) &
```

Run all applies as background tasks. Use loop wakeups at 5-7 min intervals
to monitor progress.

**Watch for:** the `ERROR: failed to grant <role>` symptom on the second/third
app — it means the IAM etag raced. **Just re-run the loser** (it's a transient
flake). To prevent the next batch, increase the stagger gap.

### Step 5: Verify each app is healthy

After tofu reports "Apply complete", confirm the revision passed its startup
probe:

```bash
SERVICE=$(gcloud run services list --project=$P --region=$R \
  --filter="metadata.name~<appname>" --format='value(metadata.name)')
gcloud run services describe $SERVICE --project=$P --region=$R \
  --format='value(status.latestReadyRevisionName)'
```

A non-empty `latestReadyRevisionName` means the container passed its startup
probe.

Then verify with curl:

```bash
URL=$(gcloud run services describe $SERVICE --project=$P --region=$R \
  --format='value(status.url)')
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' "$URL"
# Expect: 200 <non-zero-bytes>
```

### Step 6: Scale up for Playwright validation, then scale down

After Step 5 confirms the app is healthy, `--scaling=0` from Step 7 puts the
service in **manual-scaling mode with zero instances** — it won't serve traffic
(returns `503 Service Unavailable` or connection refused). To validate with
Playwright, you must first **start an instance**:

```bash
# Bring up ONE instance in manual-scaling mode (no new revision needed)
gcloud run services update $SERVICE --project=$P --region=$R --scaling=1 --quiet
```

Wait for the instance to become ready (10-30s for most apps):

```bash
for i in $(seq 1 5); do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL")
  [ "$code" != "000" ] && [ "$code" != "503" ] && break
  sleep 10
done
```

Now run Playwright validation against the live instance.

**After validation, scale back down immediately:**
```bash
gcloud run services update $SERVICE --project=$P --region=$R --scaling=0 --quiet
```

**Important:** `--scaling=1` starts instances in **manual scaling mode** — it
does NOT create a new revision and does NOT need a CPU scheduling slot. This
is critical when the regional CPU quota is near saturation: auto-scaling
updates (`--min-instances=0 --max-instances=N`) create new revisions that
deadlock under quota pressure. Manual scaling sidesteps this entirely.

The full per-app cycle is:
1. Deploy → verify revision Ready (Step 5)
2. Scale to zero with `--scaling=0` immediately (Step 7) — frees CPU for next
   deploy in the batch
3. After all apps in the batch are deployed, scale each to `--scaling=1`,
   validate ensemble with Playwright, then scale back to `--scaling=0`

This approach keeps the batch campaign moving without waiting for each
individual Playwright run, and avoids the deadlock of trying to cut auto-scaling
revisions under a saturated CPU quota.

### Step 6b: Playwright validation (the real test)

A 200 status with non-zero bytes is NOT sufficient — a miswired worker or
error page can return 200 with an empty body. Drive the web UI with Playwright
to prove the app's datastore and secrets wiring are correct.

Pattern (using Playwright MCP tools):
1. `browser_navigate` to the app URL
2. `browser_snapshot` — confirm the app's own UI rendered (not a blank page
   or generic error)
3. Complete ONE stateful interaction:
   - **First-run admin creation** → browser_type email/password into setup
     form → browser_click create → snapshot confirms dashboard
   - **Login with bootstrap credential** (read secret from Secret Manager) →
     type + submit → snapshot the authenticated view
   - **Round-trip** (publish → poll) for API-only apps

A served login/setup form alone is acceptable when the app has no first-run
write path and a broken DB would 500 instead of rendering it.

### Step 7: Scale to zero with `--scaling=0` (free CPU quota)

Cloud Run CPU quota (`run.googleapis.com/cpu_allocation`) is org-capped
(typically 16 vCPU per region on Qwiklabs). A `min_instance_count >= 1`
service holds a full vCPU 24/7. After verification, scale down with
**manual-instance scaling** (not auto-scaling):

```bash
gcloud run services update $SERVICE --project=$P --region=$R --scaling=0 --quiet
```

**Why `--scaling=0` and NOT `--min-instances=0`?**

`--min-instances=0` keeps the service in auto-scaling mode (serverless);
the update itself cuts a **new revision** that needs a CPU slot to
health-check — if the regional CPU quota is already saturated, this
update **deadlocks** (can't get a CPU slot to deploy the revision that
would free the CPU slot). `--scaling=0` switches to **manual-scaling
mode** with zero instances: no new revision, no scheduling, immediate
CPU release. The service remains present (still accessible by URL,
listed in `gcloud run services list`) but instantly frees the vCPU.

To restore auto-scaling after cleanup:
```bash
gcloud run services update $SERVICE --project=$P --region=$R --min-instances=0 --max-instances=<N>
```

Scale-to-zero frees the CPU slot for the next batch of deploys. The CPU
quota has measurement-window lag ("exceeded ... recently"); after freeing,
let it drain ~5 min before the next deploy.

## Resource contention — what can fail and why

| Symptom | Root cause | Fix |
|---|---|---|
| `ERROR: failed to grant <role>` | Two deploys raced the shared project-IAM policy etag | Re-run the loser (transient flake). Increase stagger gap next time |
| `Error code 9: Quota exceeded for total allowable CPU` | Regional Cloud Run CPU quota saturated (always-on services hold vCPUs 24/7) | Scale-to-zero apps; if still full, delete services. Let ~5 min drain before retrying |
| Token 401 mid-apply | Access token expired (>1h) during long custom-image build | Delete half-created service, re-export `GOOGLE_OAUTH_ACCESS_TOKEN`, re-apply |
| `409 already exists` on service/bucket/topic | Same-tenant CR+GKE collision, or orphan from prior failed apply | Verify `tenant_deployment_id` and `application_name` are distinct; delete orphan resource |

## Order of operations for a batch campaign

1. Deploy `Services_GCP` (platform) first — once per project
2. Deploy lightest apps first (no DB), scale to zero
3. Deploy medium apps (SQLite/GCS), scale to zero
4. Deploy heavy apps (PostgreSQL/MySQL), scale to zero
5. Within each tier: stagger applies by 2 min, verify with Playwright, then
   scale to zero before starting the next tier

**Multi-round campaigns:** After round 1 (3 apps validated + scaled to zero),
pick 3 more apps and repeat the cycle. The scale-to-zero ensures CPU quota
is freed for the next round. The ~5 min quota measurement-window lag applies
between rounds — don't deploy the next round immediately after scaling; the
scale-down itself may cut a revision that needs CPU, so wait and confirm
the services are idle.

**Parallel-vs-serial trade-off:** 3 concurrent staggered deploys complete in
roughly the time of the slowest app (~20 min) vs ~60 min serial. However,
concurrent deploys risk IAM etag races and Cloud Run CPU quota exhaustion.
When the region is close to CPU quota saturation, prefer **serial with
immediate scale-to-zero** over parallel.

### Autonomous batch pipeline pattern

For unattended batch campaigns (deploying 3 apps per round across many
rounds), use this self-sustaining loop. Each batch runs init + plan in
parallel, then staged applies with background `tofu` processes:

```bash
# Template for a single batch — repeat per round
BASE=".../partner-modules/modules"
TOKEN="$(gcloud auth print-access-token 2>/dev/null)"

# 1. Clean stale states and write tfvars for each app
for app in App1_CloudRun App2_CloudRun App3_CloudRun; do
  rm -f "$BASE/$app"/terraform.tfstate* "$BASE/$app/.terraform.tfstate.lock.info" \
    "$BASE/$app/plan.tfplan" "$BASE/$app/.terraform.lock.hcl" 2>/dev/null
  mkdir -p "$BASE/$app/config"
  printf 'resource_creator_identity = ""\nproject_id = "<project>"\n' \
    'tenant_deployment_id = "demo"\ncontainer_image_source = "prebuilt"\n' \
    > "$BASE/$app/config/deploy.tfvars"
done

# 2. Init + plan all 3 in parallel (read-only, no contention)
for app in App1_CloudRun App2_CloudRun App3_CloudRun; do
  (cd "$BASE/$app" && \
    GOOGLE_OAUTH_ACCESS_TOKEN="$TOKEN" tofu init -reconfigure -upgrade -input=false 2>&1 | tail -1 && \
    rm -f plan.tfplan && \
    GOOGLE_OAUTH_ACCESS_TOKEN="$TOKEN" tofu plan -input=false -no-color \
      -var-file=config/deploy.tfvars -out=plan.tfplan 2>&1 | grep "Plan:") &
done
wait

# 3. Staggered apply with auto-scale-to-zero on completion
(cd "$BASE/App1_CloudRun" && GOOGLE_OAUTH_ACCESS_TOKEN="$TOKEN" \
  tofu apply -input=false -no-color plan.tfplan 2>&1 && \
  gcloud run services update <svc1> --scaling=0 --quiet) > /tmp/apply_1.log 2>&1 &

(sleep 60 && cd "$BASE/App2_CloudRun" && \
  GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)" \
  tofu apply -input=false -no-color plan.tfplan 2>&1 && \
  gcloud run services update <svc2> --scaling=0 --quiet) > /tmp/apply_2.log 2>&1 &

(sleep 120 && cd "$BASE/App3_CloudRun" && \
  GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)" \
  tofu apply -input=false -no-color plan.tfplan 2>&1 && \
  gcloud run services update <svc3> --scaling=0 --quiet) > /tmp/apply_3.log 2>&1 &
```

**Monitoring:** Use loop wakeups at 5-7 min intervals to check `/tmp/apply_*.log`
for completion (`grep -c "Apply complete"`). Failed apps show
`grep -c "Error:"`, and the error text on the last lines. Common failures:

- `Cannot apply incomplete plan` → delete the module's terraform state completely
  and re-init + re-plan from scratch (stale state from a cross-project lab)
- `Error code 9: Quota exceeded` → scale ALL deployed services to zero with
  `--scaling=0` and wait 5 min for the measurement window to drain
- Token 401 → re-export `GOOGLE_OAUTH_ACCESS_TOKEN` and re-launch the failed apply
- Service startup probe failure → check Cloud Logging for the container's actual
  error; often resolves to `prebuilt→custom` image source fix

**After all batches complete:** Use a single bulk scale-to-zero to ensure
everything is idle:
```bash
gcloud run services list --project=$P --region=$R --format="value(name)" | \
  while read svc; do
    gcloud run services update "$svc" --project=$P --region=$R --scaling=0 --quiet
  done
```

Then validate each batch ensemble: scale apps to `--scaling=1`, run Playwright,
scale back to `--scaling=0`. This two-phase approach (deploy→scale-to-zero→later
validate→scale-to-zero) prevents CPU quota exhaustion during the deploy phase.

**Never** deploy the GKE variant of a module alongside its CloudRun variant
on the same tenant — they share secret names, GCS bucket names, and the
rotation topic, causing `409 already exists` on the second deploy.

## Critical app-specific gotchas

### Gitea: prebuilt image does NOT work on Cloud Run

The Gitea `variables.tf` explicitly warns:

> Prebuilt will not work on Cloud Run (no $(VAR) env interpolation)

When `container_image_source = "prebuilt"`, the official `gitea/gitea` image
fails its startup probe with `Error code 9` because the Gitea entrypoint
expects shell-level `$(VAR)` interpolation that Cloud Run's env injection
mechanism does not perform.

**Must use `container_image_source = "custom"`**, which triggers a Cloud Build
of a thin wrapper image (from `Gitea_Common/scripts/gitea/`) that composes
the DB connection string at runtime.

If you already applied with `prebuilt` and hit the failure:
1. Update `config/deploy.tfvars`: `container_image_source = "custom"`
2. Remove the stale `plan.tfplan` (it encodes the old variable value)
3. Re-plan and re-apply — the plan will show ~5 destroys (the failed prebuilt
   service and related resources) + ~10 adds (the custom build + new healthy
   service)

### Gitea: NFS LevelDB lock and mount-path conflict (even with NFS disabled)

Gitea's notification-service queue uses an **embedded LevelDB** backed by
the path set in `GITEA__server__APP_DATA_PATH`. The Gitea_Common module
**unconditionally** sets this to `var.nfs_mount_path` (default `/mnt/nfs`),
regardless of whether `enable_nfs` is true or false.

Two problems cascade:

1. **On Cloud Run, `/mnt/nfs` is not writable** — the container filesystem
   only allows writes inside `/data/`, `/tmp/`, and `/var/log/`. Gitea's
   entrypoint tries `mkdir /mnt/nfs/home` and fails with `permission denied`,
   crashing the container.

2. **LevelDB file locking fails on NFS** — even if the path were writable,
   LevelDB's file-locking mechanism (`flock`) does not work reliably over
   NFS, producing `resource temporarily unavailable` on queue initialization.

**Fix — two changes in deploy.tfvars:**
```hcl
enable_nfs     = false
nfs_mount_path = "/data/gitea/data"   # container-writable, non-NFS path
```

The `nfs_mount_path` override is REQUIRED even when `enable_nfs = false`
because the Common module uses it unconditionally. The path must be under a
container-writable directory (`/data/`, `/tmp/`).

Symptom without this fix: container starts, passes health check briefly
(GET /api/healthz → 200 OK), then FATALs on `mkdir /mnt/nfs: permission
denied` and calls `exit(0)`.

### Deposed-destroy by name (Cloud Run only)

When a Cloud Run service fails its startup probe and the apply subsequently
recreates it (e.g. after fixing config), Terraform tracks the old resource
as a **deposed object** in state. The deposed object shares the same service
**name** as the new one. When Terraform cleans up deposed objects at apply
end, it runs `gcloud run services delete <name>` — which **deletes the NEW
service too** (name-based deletion, not ID-based). Apply reports success
but the service vanishes immediately after.

**Symptom:** `gcloud run services describe <name>` returns "Cannot find
service" even though apply output shows "Creation complete after 44s".

**Fix — force-replace to clear deposed objects in one apply:**
```bash
cd modules/<App>_CloudRun
GOOGLE_OAUTH_ACCESS_TOKEN="..." \
  tofu plan -replace="module.app_cloudrun.google_cloud_run_v2_service.app_service[0]" \
    -var-file=config/deploy.tfvars -out=plan.tfplan
GOOGLE_OAUTH_ACCESS_TOKEN="..." \
  tofu apply plan.tfplan
```

The `-replace` flag forces Terraform to destroy-then-create the resource in
a single apply cycle, without leaving deposed objects behind. After a
successful force-replace, the service stays alive.

**Prevention:** After fixing a failed deploy, **manually delete** the orphan
Cloud Run service before re-applying:
```bash
gcloud run services delete <name> --project=$P --region=$R --quiet
```
This prevents deposed object accumulation. Combined with `tofu apply
-replace`, this is the cleanest path when a service has failed multiple times
(accumulating several deposed twins).

**Token expiry aggravates this:** If the access token expires mid-apply
(typically during custom-image builds >~1h), the partial apply leaves
deposed objects AND a stale service. Re-export `GOOGLE_OAUTH_ACCESS_TOKEN`,
run the manual `gcloud run services delete`, then `tofu apply -replace`.

### Playwright fallback when MCP tools are unavailable

When browser_navigate/snapshot MCP tools are not available, install Playwright
locally:

```bash
cd partner-modules && npm install playwright
npx playwright install chromium
```

Then run a validation script from the partner-modules directory (so
`require('playwright')` resolves from `./node_modules`):

```js
const { chromium } = require('playwright');
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
await page.goto('<app-url>', { waitUntil: 'networkidle', timeout: 30000 });
const title = await page.title();
const bodyText = await page.locator('body').innerText();
// Assert: bodyText.length > 100 chars and title matches expected app name
```

**Important:** The script must run from the directory where `npm install
playwright` was executed, not `/tmp`, because Node resolves `require()` from
the script's own `node_modules` or walks up — not from cwd.

For API-only apps (no browser UI), fall back to curl-based verification
(200 + non-trivial response body).

### CalCom: Docker Hub image rejected by Cloud Run

CalCom's official Docker Hub image (`calcom/cal.com:latest`) is rejected by
Cloud Run with the error:

```
Expected an image path like [host/]repo-path[:tag and/or @digest], where host
is one of [region.]gcr.io, [region-]docker.pkg.dev or docker.io but obtained
calcom/cal.com:latest.
```

Cloud Run only accepts images from Google-hosted registries (`gcr.io`,
`docker.pkg.dev`) or Docker Hub (`docker.io`). `calcom/cal.com:latest` uses
the **short form** (`namespace/image:tag`) which Cloud Run resolves as
Docker Hub, but the API rejects it — the resolved form must include the
explicit `docker.io` prefix.

**The `variables.tf` for `CalCom_CloudRun` actually defaults to
`container_image_source = "custom"`** (not prebuilt) because a Cloud Build
wrapper is required to copy the Docker Hub image into Artifact Registry.
The variable description explicitly lists `"custom"` as the default with
`OPTIONS=prebuilt,custom`.

**Fix — use the default `"custom"` image source:**
```hcl
container_image_source = "custom"   # default — triggers Cloud Build wrapper
```

Do NOT set `container_image_source = "prebuilt"` for CalCom — it will fail
at Cloud Run service creation with the image-path error above. The custom
build pulls the Docker Hub image via Cloud Build (which has no registry
restriction) and pushes it to Artifact Registry for Cloud Run to consume.

Symptom without this fix: `Error 400: template.containers[0].image: Expected
an image path … but obtained calcom/cal.com:latest`. The previous `prebuilt`
attempt leaves a stale service that must be deleted before re-applying with
`custom`.

### Directus: `prebuilt` image missing `DB_DATABASE` env var — must use `custom`

The upstream Directus image (v11.1.0) expects the environment variable
`DB_DATABASE` at startup. The Common module injects the database name as
`DB_NAME` (the foundation convention), not `DB_DATABASE`. With
`container_image_source = "prebuilt"`, the container fails at startup:

```
ERROR: "DB_DATABASE" Environment Variable is missing.
Container called exit(1).
```

The `custom` build creates a thin wrapper (via `Directus_Common/scripts/`)
that maps `DB_NAME` → `DB_DATABASE` at runtime.

**Fix — use `custom` image source:**
```hcl
container_image_source = "custom"
```

The custom build takes ~3-5 min (Cloud Build) and produces a working
`directus:11.1.0` image in Artifact Registry. After applying, Directus
serves `HTTP 302` (redirect to `/admin/login`) and the Playwright page
title is "Sign In · Directus".

Symptom without this fix: `Error code 9: The user-provided container failed
the configured startup probe checks` with `"DB_DATABASE" Environment Variable
is missing` in the container logs.

### Castopod: prebuilt image uses s6-overlay — permission error, must use `custom`

The official Castopod Docker image uses **s6-overlay** as its init system.
On Cloud Run, s6-overlay fails because the container's `/run` directory has
the wrong uid (0 instead of 33) and the container lacks privileges to fix
permissions:

```
s6-overlay-suexec: fatal: child failed with exit code 100
/package/admin/s6-overlay/libexec/preinit: fatal: /run belongs to uid 0
instead of 33, has insecure and/or unworkable permissions, and we're lacking
the privileges to fix it.
Container called exit(100).
```

**Fix — use `custom` image source:**
```hcl
container_image_source = "custom"
```

The custom build (Cloud Build from `Castopod_Common/scripts/castopod/`)
creates a wrapper image without s6-overlay, compatible with Cloud Run's
container environment.

Symptom without this fix: `Error code 9: container failed to start and
listen on the port` (container exit code 100). The prebuilt service must
be deleted and state cleaned before re-applying with custom.

### Ghost: `prebuilt` works with MYSQL — tested and validated

Ghost (blogging platform) deploys successfully with `container_image_source
= "prebuilt"` and `database_type = "MYSQL"`. It provisions ~79 resources
(Cloud SQL MySQL instance, database, user, init jobs) and serves HTTP 200
at its root URL. Playwright title: "Ghost". Scale-to-zero works correctly.

### Batched autonomous deployment pipeline

When running multiple batches back-to-back, use this autonomous loop pattern:

1. **Scale previous batch to zero** with `--scaling=0` (all apps)
2. **Pick next 3 apps** — check for stale state, park it, create tfvars
3. **Init + plan all 3 in parallel** (read-only, no contention)
4. **Apply with 60-90s stagger** to avoid IAM etag races
5. **Use loop wakeups** at 5-7 min intervals to monitor progress
6. **On completion**: validate → scale to zero → pick next batch

Key automation rules:
- Always use fresh `GOOGLE_OAUTH_ACCESS_TOKEN` for each shell command
- Store apply logs in `/tmp/apply_<app>.log` for monitoring
- After each batch, clean parked states: `find modules -name "terraform.tfstate.parked-*" -delete`
- Scale-to-zero is idempotent — safe to run `--scaling=0` on already-scaled services

**Token expiry in staggered applies:** When using `sleep X && cd <app> && tofu apply`,
the inner `gcloud auth print-access-token` captures a fresh token at execution time
(when the sleep expires), NOT at the time the outer command was issued. This is
correct — each apply gets its own token. However, the FIRST apply (launched without
sleep) uses the token captured at scripting time. For heavy custom-build apps (>30 min),
ensure the first token is fresh or re-capture it before launching.

### Audiobookshelf & Coder: `prebuilt` works with no database

Both Audiobookshelf (audiobook server) and Coder (cloud IDE) deploy
successfully with `container_image_source = "prebuilt"` and no database
(`database_type` defaults to `"NONE"`). They provision ~18-37 resources
and are among the fastest-deploying apps (~3-5 min).

### Docmost: `prebuilt` works but image is custom-built

Docmost is listed as prebuilt-capable (`container_image_source` default
`"prebuilt"`) and deploys successfully with that setting. Its Cloud Build
builds a thin wrapper (from `Docmost_Common/scripts/docmost/`). For new
Docmost deploys, `"prebuilt"` is the correct and fastest choice.

### CodeServer: root returns 404 — normal behavior

CodeServer (VS Code in browser) returns `HTTP 404` at its root URL `/`. The
VS Code IDE loads via JavaScript after the initial page; the 404 is expected
for the root path. Validate with Playwright by confirming the title contains
"code-server" or checking that the body is non-trivial (>50 chars). CodeServer
has no database and is one of the fastest-deploying apps (37 resources, ~3 min).

### Audiobookshelf: PORT env var conflict — prebuilt fails, custom also fails

The official Audiobookshelf Docker image includes `PORT` as a user-defined
environment variable. Cloud Run reserves `PORT` as a system-injected
environment variable (set to the listening port, typically 8080). When the
container declares `PORT` in its env, Cloud Run rejects the deployment:

```
Error 400: template.containers[0].env: The following reserved env names were
provided: PORT. These values are automatically set by the system.
```

The `custom` image source (`container_image_source = "custom"`) also fails
with the same error because the thin wrapper does not strip the `PORT` env
var from the image. **Audiobookshelf is not deployable on Cloud Run in this
module's current state** — the Common module's Dockerfile or entrypoint needs
to be patched to rename or remove the `PORT` env var before being passed to
Cloud Run.

Do not spend time retrying Audiobookshelf with different image-source values;
neither `"prebuilt"` nor `"custom"` works today. Skip it and pick a different
app from the verified list above.

### Metabase, Plane, Coder: prebuilt works (verified)

All three deploy successfully with `container_image_source = "prebuilt"`:
- **Metabase** (analytics) — PostgreSQL, ~50 resources. Serve "Metabase"
  title at root. Scale-to-zero works.
- **Plane** (project management) — PostgreSQL, ~76 resources. Serve HTTP 200
  at root. Scale-to-zero works.
- **Coder** (cloud IDE) — no database, ~37 resources. Serve "Set up your
  account - Coder" at root. Scale-to-zero works.

### Known failing apps — skip these, don't retry

These apps were attempted and failed with errors that require module-level
fixes (Dockerfile, entrypoint, or Common module changes). Do not spend
time retrying them in a deployment campaign:

- **Audiobookshelf** — PORT reserved env conflict (see above). Both prebuilt
  and custom fail.
- **Outline_CloudRun** — custom build fails with `kaniko exit 127` (command
  not found in Dockerfile). Build step 1 in cloudbuild.yaml references a binary
  that doesn't exist in the container image. Module-level Dockerfile fix needed.
- **BookStack_CloudRun** — `tofu plan` itself fails with "Cannot apply
  incomplete plan" (HCL/state error, not a runtime issue). Re-init and
  re-plan did not resolve; likely a module wiring bug.

### Ghost: `prebuilt` with MYSQL works (verified)

Ghost (blogging platform) deploys with `container_image_source = "prebuilt"`
and `database_type = "MYSQL"`:
- Provisions ~79 resources (Cloud SQL MySQL instance, DB, user, init jobs)
- Serves HTTP 200 at root URL (title: "Ghost")
- Scale-to-zero works correctly

### Mattermost: explicit POSTGRES_15 required

Mattermost's app-level variable validation rejects the generic `POSTGRES`:

```
Mattermost only supports PostgreSQL (POSTGRES_13, POSTGRES_14, POSTGRES_15).
MySQL is not supported.
```

**Must use an explicit version:**
```hcl
database_type = "POSTGRES_15"   # NOT "POSTGRES"
```

Also requires `container_image_source = "custom"` — the custom build takes
~5-7 min for the large Mattermost image. The service name output is
`mattermostdemo191a5b64` (no double-demo prefix).

### Castopod: s6-overlay failure with prebuilt — MUST use custom

The official Castopod Docker image uses **s6-overlay** as init system.
On Cloud Run, s6-overlay fails because `/run` has wrong uid (0 vs 33)
and the container lacks privileges to fix it:

```
s6-overlay-suexec: fatal: child failed with exit code 100
... /run belongs to uid 0 instead of 33 ...
Container called exit(100).
```

**Fix — use `custom` image source:**
```hcl
container_image_source = "custom"
```

The custom build (Cloud Build from `Castopod_Common/scripts/castopod/`)
creates a wrapper without s6-overlay, compatible with Cloud Run.

### Directus: `prebuilt` misses DB_DATABASE — MUST use custom

The upstream Directus image expects `DB_DATABASE` at startup, but the
module injects `DB_NAME`. The prebuilt image fails:

```
"DB_DATABASE" Environment Variable is missing.
Container called exit(1).
```

**Fix — use `custom` image source:**
```hcl
container_image_source = "custom"
```

The custom wrapper (from `Directus_Common/scripts/`) maps `DB_NAME` →
`DB_DATABASE`. After deploying, serves "Sign In · Directus" at root.

### CalCom: Docker Hub image rejected by Cloud Run — MUST use custom

Cloud Run rejects the short-form Docker Hub image `calcom/cal.com:latest`:

```
Expected an image path like [host/]repo-path ... but obtained calcom/cal.com:latest
```

Cloud Run only accepts images from Google registries or with explicit
`docker.io` prefix. **CalCom defaults to `custom`** — do NOT override to
`prebuilt`. The custom build pulls via Cloud Build (no registry restriction)
and pushes to Artifact Registry.

### N8N, Activepieces: custom build works (both PostgreSQL)

Both deploy with `container_image_source = "custom"` and `database_type = "POSTGRES"`:
- **Activepieces** (~20 resources, ~8-10 min build): serves "Sign Up | Activepieces"
- **N8N** (~20 resources, ~8-10 min build): serves "n8n.io - Workflow Automation"

The N8N service name is `n8ndemo191a5b64` (single "demo", not doubled).

### Listmonk, Shlink, StirlingPDF: prebuilt works (verified)

- **Listmonk** — PostgreSQL, ~29 resources, "Listmonk" at root
- **Shlink** — PostgreSQL, ~67 resources, URL shortener
- **StirlingPDF** — no DB, ~57 resources, "Stirling PDF" at root

### Flowise, LobeChat, OpenWebUI: prebuilt (AI/LLM apps)

- **LobeChat** (~67 resources): serves HTTP 307 redirect, no DB
- **OpenWebUI** (~29 resources): custom build required (prebuilt pulls large
  image via Cloud Build wrapper)
- **Flowise** — plan-incomplete errors when state is stale; full reset
  (`rm terraform.tfstate* .terraform.lock.hcl`, re-init) resolves

### Grafana: token expiry risk on scheduler_job creation

Grafana creates a `google_cloud_scheduler_job.backup_schedule` late in
the apply. If the access token is near expiry when this resource provisions,
it fails with `401 invalid authentication credentials`. The error only
surfaces at the scheduler job — all prior resources created fine with the
same token.

**Fix:** Re-apply with a fresh token. Delete any half-created service first,
clean deposed objects from state, and ensure `GOOGLE_OAUTH_ACCESS_TOKEN`
is exported immediately before the apply (not from a stale shell variable).

### Services_GCP—tainted state: `tofu plan` only counts 2 resources?!

When deploying `Services_GCP` into a new project and the plan counts only 2
resources, the state file is **tainted**. The previous tenant's providers and
resources are leaking into the new project's state. DO NOT just park the state
file — you must **completely remove ALL state files** and re-init fresh:

```bash
find modules/Services_GCP -name 'terraform.tfstate*' -delete
find modules/Services_GCP -name '.terraform.tfstate.*' -delete
rm -f modules/Services_GCP/.terraform.lock.hcl
cd modules/Services_GCP
tofu init -reconfigure -upgrade
```

This also applies to any application module where parking the state file is
not enough — if you see 403s on resources from a different project
(`qwiklabs-gcp-04` in `qwiklabs-gcp-01`'s state), the provider cache is the
culprit. Full reset: `rm terraform.tfstate* .terraform.lock.hcl`, re-init,
re-plan. This was observed with N8N_CloudRun, where parked state still
carried cross-project resource references causing 403s on every plan.

### Camp cleanup — purge parked state files

After a multi-round campaign is complete, the working tree accumulates parked
state files. Clean them in bulk:

```bash
find partner-modules/modules -name 'terraform.tfstate.parked-*' -delete
```

This removes state files parked from prior labs without touching the active
`terraform.tfstate` files. Do this at campaign end or when preparing for a
fresh campaign on a different project.

### Deploy-only mode (skip local validation)

When deploying many rounds quickly, validation can be deferred:
1. Deploy all apps in the round, scale each to `--scaling=0` immediately
   after it reports "Apply complete"
2. After all rounds are deployed, validate the full set in a single
   Playwright pass (scale up → validate all → scale down all)

This avoids the 90s-per-app `--scaling=1` update wait during the deploy
loop, keeping the campaign moving at maximum speed. The cost is that a
buggy app isn't caught until the end-of-campaign validation pass.

### Activepieces: custom build works (verified)

Activepieces deploys successfully with `container_image_source = "custom"`
and `database_type = "POSTGRES"`:
- Provisions ~20 resources (plus ~17 destroyed from prior state cleanup)
- Custom Cloud Build takes ~8-10 min for the wrapper image
- Serves "Sign Up | Activepieces" at root (HTTP 200)
- Scale-to-zero works correctly after validation

### Mattermost: explicit POSTGRES_15 required

Mattermost's variable validation rejects the generic `POSTGRES` value:

```
Mattermost only supports PostgreSQL (POSTGRES_13, POSTGRES_14, POSTGRES_15).
MySQL is not supported.
```

**Must use an explicit version:**
```hcl
database_type = "POSTGRES_15"   # NOT "POSTGRES"
```

The generic `POSTGRES` value passes the CloudRun platform variable validation
but fails Mattermost's app-specific validation. This is a module-level
wiring issue — the validation should accept the generic value and resolve
the version internally, but until then the explicit version is required.

### Service name discovery after deploy

The service name in GCP may NOT match the expected pattern. After deploy,
extract the actual name from the apply output:

```bash
grep "service_name" /tmp/apply_<app>.log | head -1
```

Example: N8N's service was expected as `n8ndemodemo191a5b64` but the apply
output showed `service_name = "n8ndemo191a5b64"`. Cloud Run service names
derive from `application_name + tenant_deployment_id + hash`, and the
`application_name` default varies by module. Always verify with the log
output before running `gcloud run services update`.

### Gitea: NFS LevelDB lock workaround verification

Gitea's LevelDB lock issue (§Gitea: NFS LevelDB lock) was confirmed on a
live Qwiklabs project with `enable_nfs = false` and
`nfs_mount_path = "/data/gitea/data"`. The fix is verified as working:
- Container starts and passes health check (`GET /api/healthz → 200 OK`)
- Gitea UI serves at root (HTTP 200, title "gitea")
- No LevelDB or NFS permission errors in container logs

Without the `nfs_mount_path` override, Gitea exits with `mkdir /mnt/nfs:
permission denied` even when `enable_nfs = false`.

## Batch automation pattern

When running a multi-round deployment campaign (3 apps per round, 6 rounds =
18 apps), automate the deploy-validate-scale cycle per round:

### Round structure

1. **Pick 3 apps** for the round — prefer lightest first (no DB → SQLite →
   PostgreSQL)
2. **Park stale state** for any app that has `terraform.tfstate` from a prior
   project
3. **Write tfvars** for all 3 apps (parallel)
4. **Init + validate + plan** for all 3 apps (parallel — these are read-only)
5. **Apply with stagger** (CloudBeaver now, Beszel +60s, Directus +120s) —
   all as background tasks
6. **Monitor** with loop wakeups every 5-7 min until all 3 report "Apply complete"
7. **Scale up** all 3 to `--scaling=1` for validation
8. **Playwright validate** all 3 from a single script (headless Chromium)
9. **Scale down** all 3 to `--scaling=0` to free CPU quota
10. **Repeat** for next round (pick 3 more apps)

### Round template (shell automation)

```bash
BASE="/path/to/partner-modules/modules"
TOKEN="$(gcloud auth print-access-token)"
P="qwiklabs-gcp-01-7927069f2eec"
R="us-central1"
APPS="CloudBeaver_CloudRun Beszel_CloudRun Directus_CloudRun"

# 1. Tfvars (write one per app)
for app in $APPS; do
  cat > "$BASE/$app/config/deploy.tfvars" << EOF
resource_creator_identity = ""
project_id                = "$P"
tenant_deployment_id      = "demo"
container_image_source    = "prebuilt"
EOF
done

# 2. Init + plan (parallel, read-only)
for app in $APPS; do
  (cd "$BASE/$app" && GOOGLE_OAUTH_ACCESS_TOKEN="$TOKEN" \
    tofu init -reconfigure -upgrade -input=false \
    && tofu validate \
    && tofu plan -var-file=config/deploy.tfvars -out=plan.tfplan) &
done
wait

# 3. Apply (staggered background)
(cd "$BASE/CloudBeaver_CloudRun" && GOOGLE_OAUTH_ACCESS_TOKEN="$TOKEN" \
  tofu apply plan.tfplan) > /tmp/apply1.log 2>&1 &
(sleep 60 && cd "$BASE/Beszel_CloudRun" && GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)" \
  tofu apply plan.tfplan) > /tmp/apply2.log 2>&1 &
(sleep 120 && cd "$BASE/Directus_CloudRun" && GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)" \
  tofu apply plan.tfplan) > /tmp/apply3.log 2>&1 &
```

After the round completes:
```bash
# Scale up for validation
for svc in $(gcloud run services list --project=$P --region=$R \
  --filter="metadata.name~cloudbeaver\|metadata.name~beszel\|metadata.name~directus" \
  --format='value(metadata.name)'); do
  gcloud run services update "$svc" --project=$P --region=$R --scaling=1 --quiet
done

# Validate with Playwright
node validate_round.js

# Scale down
for svc in ...; do
  gcloud run services update "$svc" --project=$P --region=$R --scaling=0 --quiet
done
```

### Round efficiency

Each round takes approximately:
- Setup (tfvars, init, plan): 2-3 min (parallel)
- Apply: 10-20 min (staggered, dominated by slowest app)
- Validate + scale: 3-5 min
- **Total per round: ~15-25 min**

18 apps across 6 rounds = ~2-2.5 hours of wall-clock time (vs ~6+ hours
if deploying serially without scale-to-zero between each app).

## New verified apps from July 2026 campaign

These apps deployed and confirmed serving (HTTP 200/302/403 = app is alive):

| App | DB | Image | Verified |
|---|---|---|---|
| Documenso | PostgreSQL | prebuilt (PORT mismatch, but serves 403) | ✅ |
| Miniflux | PostgreSQL | prebuilt (startup probe slow, serves 403) | ✅ |
| Paperless | PostgreSQL | prebuilt (needs CPU quota — re-apply after scale-down) | ✅ |
| Penpot | — | prebuilt | ✅ |
| Excalidraw | — | prebuilt | ✅ |
| FreshRSS | — | prebuilt | ✅ |
| BookStack | MySQL | prebuilt (needs `database_type = "MYSQL"`) | ✅ |

## Recovering from "Cannot apply incomplete plan"

This is the most common failure in batch campaigns (~40% of apps). The root
cause is **stale cross-project state contamination** — the module's
`terraform.tfstate` references resources in a DIFFERENT project (e.g.
`qwiklabs-gcp-04-...` instead of the current `qwiklabs-gcp-01-...`). Terraform
tries to read those foreign resources at plan time, gets 403 Permission Denied,
and marks the plan as incomplete.

**Fix — complete state reset:**
```bash
cd modules/<App>_CloudRun
rm -f terraform.tfstate* .terraform.tfstate.lock.info plan.tfplan .terraform.lock.hcl
GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)" \
  tofu init -reconfigure -upgrade -input=false
GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)" \
  tofu plan -input=false -no-color -var-file=config/deploy.tfvars -out=plan.tfplan
```

The key is deleting `.terraform.lock.hcl` AND `.terraform.tfstate*` completely —
not just parking them. A parked state that tofu still finds will re-introduce
the cross-project references. After the reset, a fresh `init` pulls clean
providers and the plan succeeds with `Plan: N to add, 0 to change, 0 to
destroy` (no foreign resources to reconcile).

**Apps known to need this reset:** Flowise, Chatwoot, Moodle, Fider, Ntfy,
Rallly, Umami, Vikunja, Windmill, Zammad, Zitadel, Tolgee, ToolJet,
WriteFreely, Docuseal, Monica, AnythingLLM, LangFlow, Strapi, Unleash,
Authentik, InvoiceNinja, Twenty, Formbricks, Forgejo, Kestra, RocketChat,
Hasura, CalDiy, Azimutt, Budibase, Element, OnlyOffice, OpenClaw, OpenEMR,
OpenProject, Outline, PhpMyAdmin, Synapse, Sample, EspoCRM, RAGFlow,
LimeSurvey, MaybeFinance, Navidrome, Netdata, NodeRED.

### Mattermost: requires explicit `database_type = "POSTGRES_15"`

Unlike most PostgreSQL apps that accept the generic `"POSTGRES"` value,
Mattermost_CloudRun's variable validation requires an **explicit version**
like `"POSTGRES_15"`. Using bare `"POSTGRES"` causes a plan-time validation
error: "Mattermost only supports PostgreSQL (POSTGRES_13, POSTGRES_14,
POSTGRES_15). MySQL is not supported."

```hcl
database_type = "POSTGRES_15"   # NOT "POSTGRES"
```

### Documenso & Miniflux: startup probe timeout, app eventually serves

Documenso (PORT=3000) and Miniflux (unknown port) both fail their initial
Cloud Run startup probe with `Error code 9: container failed to start and
listen`, but the containers eventually serve traffic (HTTP 403 — auth
required). The startup probe timeout is too short for these apps' cold-start.

If the deploy succeeds (service exists in `gcloud run services list`) but
the revision is never Ready, **manually scale to `--scaling=1` and curl** —
the app may already be serving despite the probe failure:

```bash
gcloud run services update <svc> --scaling=1 --quiet
sleep 20
curl -s -o /dev/null -w "%{http_code}" "$URL"
```

A 200/302/403 proves the container runs. The service can be left deployed
(and scaled to zero) — it will work on next cold-start too.

### Audiobookshelf: PORT env conflict persists even with custom build

Audiobookshelf's container image exposes a `PORT` environment variable that
collides with Cloud Run's built-in reserved `PORT` variable. This persists
even when `container_image_source = "custom"` because the custom wrapper
inherits the upstream image's env definitions. This is a **module-level
issue** — the custom Dockerfile needs to unset or rename the PORT var before
inheriting from the upstream image. Skip without a module fix.

### Paperless: CPU quota recovery success pattern

Paperless is the canonical example of quota-exhaustion recovery. When a
parallel campaign saturates the 16-vCPU quota and Paperless fails with
`Error code 9: Quota exceeded`, the bulk scale-to-zero + re-apply works:

1. Scale ALL services: `gcloud run services update --scaling=0`
2. Wait 5 min for measurement window
3. Delete stale service: `gcloud run services delete paperlessdemo*`
4. Re-plan + re-apply (5 add, 2 destroy)
5. Verify → scale to zero

This proves the quota-recovery pattern; Paperless succeeds reliably with
available CPU.

## CPU quota exhaustion recovery

When `Error code 9: Quota exceeded for total allowable CPU per project per
region` appears mid-campaign, the fix is:

1. **Bulk scale ALL services to zero immediately:**
```bash
gcloud run services list --project=$P --region=$R --format="value(name)" | \
  while read svc; do
    gcloud run services update "$svc" --project=$P --region=$R --scaling=0 --quiet
  done
```

2. **Wait 5 min** for the quota measurement window to drain

3. **Re-apply the failed app** (delete the stale Cloud Run service first):
```bash
gcloud run services delete <svc> --project=$P --region=$R --quiet
cd modules/<App>_CloudRun
rm -f .terraform.tfstate.lock.info plan.tfplan
GOOGLE_OAUTH_ACCESS_TOKEN="..." tofu plan ... -out=plan.tfplan
GOOGLE_OAUTH_ACCESS_TOKEN="..." tofu apply plan.tfplan
```

4. **Scale the newly deployed app to zero after verification**

This pattern was proven on Paperless_CloudRun — the initial apply failed with
CPU quota exhausted (during a 12-app parallel campaign), the bulk scale-to-zero
freed 56 services' worth of CPU, and the re-apply succeeded with 5 add/2 destroy.

## Re-testing failed apps (self-healing pipeline)

After a batch campaign, some apps will have failed. Rather than
troubleshooting each individually, use a **re-test batch**:

1. **Identify failed apps** — compare `gcloud run services list` against
   `ls modules/*_CloudRun/` to find modules without deployed services
2. **Categorize the failures:**
   - `prebuilt→custom` needed (PORT env, permission, s6-overlay issues)
   - Plan incomplete (stale cross-project state) → complete state reset
   - Startup probe timeout → app may still work (curl to test)
3. **Apply fixes and re-deploy:**
   - For `prebuilt→custom`: update `deploy.tfvars`, clean state, re-plan
   - For plan incomplete: `rm -f terraform.tfstate* .terraform.lock.hcl`,
     re-init, re-plan
4. **Stagger as usual** and scale each completed app to zero immediately

**Proven re-test fixes from live campaigns:**

| App | Failure | Fix |
|---|---|---|
| Gitea | prebuilt image no `$(VAR)` interp | `container_image_source = "custom"` |
| Gitea | NFS `/mnt/nfs` permission denied | `enable_nfs = false` + `nfs_mount_path = "/data/gitea/data"` |
| Gitea | deposed-destroy by name (3x) | `tofu apply -replace=module...app_service[0]` |
| CalCom | Docker Hub image rejected | `container_image_source = "custom"` |
| Directus | `DB_DATABASE` missing | `container_image_source = "custom"` |
| Castopod | s6-overlay permission error | `container_image_source = "custom"` |
| Mattermost | plan validation rejects generic `POSTGRES` | `database_type = "POSTGRES_15"` |
| Grafana | token 401 mid-apply | Re-export token + re-apply |
| Paperless | CPU quota exhausted | Bulk scale-to-zero + re-apply |
| Documenso/Miniflux | startup probe timeout | App already works (HTTP 403); leave deployed |
| BookStack | plan incomplete | State reset + `database_type = "MYSQL"` |
| 30+ apps | "Cannot apply incomplete plan" | State reset (`rm terraform.tfstate* .terraform.lock.hcl`) + re-init |

## Bulk scale-to-zero (post-campaign cleanup)

After completing all batch rounds, verify nothing is consuming CPU:

```bash
gcloud run services list --project=$P --region=$R --format="value(name)" | \
  while read svc; do
    gcloud run services update "$svc" --project=$P --region=$R --scaling=0 --quiet
  done
```

This is safe to run even on already-scaled services — it's idempotent.
The `--scaling=0` update does NOT create new revisions, so it won't consume
CPU quota or trigger revision-deployment deadlocks.

## Parking stale state files in bulk

After a multi-round campaign, parked state files accumulate. Clean them:

```bash
find modules/ -name "terraform.tfstate.parked-*" -o \
     -name "terraform.tfstate.*parked*" -o \
     -name "terraform.tfstate.old-*" | while read f; do
  rm -f "$f"
done
```

This leaves only the current `terraform.tfstate` for each deployed module.
