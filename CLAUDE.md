# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

`rad-modules` is a catalog of standalone OpenTofu/Terraform modules that deploy educational Google Cloud and multi-cloud Kubernetes reference architectures ("RAD Lab"). Modules are deployed via the interactive `rad-launcher` CLI or via Cloud Build pipelines driven by the RAD platform UI.

## Common Commands

All Terraform commands run from **within a module directory** (e.g. `cd modules/Istio_GKE`):

```bash
# Validate and format-check a module
tofu init -backend=false
tofu validate
tofu fmt -check

# Run module-level tests (uses mock providers, no GCP credentials needed)
tofu test

# Plan/apply with a real project
tofu plan  -var="project_id=my-gcp-project"
tofu apply -var="project_id=my-gcp-project"
tofu destroy -var="project_id=my-gcp-project"
```

Lint all modules from the repo root:
```bash
# Format check (CI uses terraform, but tofu also works)
terraform fmt -check -recursive modules/

# tflint (run from within a module directory)
tflint --init --config ../../.tflint.hcl
tflint --config ../../.tflint.hcl --format compact
```

Run the interactive launcher:
```bash
cd rad-launcher
python3 installer_prereq.py   # install prerequisites once
python3 radlab.py             # interactive module deploy/destroy
```

Non-interactive launcher:
```bash
python3 rad-launcher/radlab.py \
  -m Istio_GKE -a create \
  -p my-mgmt-project -b my-mgmt-project-radlab-tfstate \
  -f /path/to/my.tfvars
```

**Before running `tofu plan`/`apply` directly against a module directory (bypassing the launcher), check for leftovers from a prior manual run:**
- `ls *.auto.tfvars` — OpenTofu loads these automatically with no `-var-file` flag. A stale one from an earlier lab pins `project_id` (or other vars) to a project you may no longer have access to, and the failure mode is a confusing 403 deep in `plan`, not an obviously-wrong-input error. `Bank_GKE` has shipped one before; there is no repo convention preventing another.
- `ls *.tfstate*` — local state from a previous run against a *different* project makes `plan` try to reconcile resources that don't exist in the target project. The launcher and `rad-ui` always use a GCS backend and never hit this; a bare `tofu init`/`apply` in a module directory does.

**Credentials are machine-global, not session-scoped.** `gcloud auth application-default login` overwrites the single `~/.config/gcloud/application_default_credentials.json` for every terminal and every tool on the machine — including a concurrent session mid-`tofu apply`. `gcloud config configurations` does not isolate this; the configuration files themselves live in the same shared `~/.config/gcloud/` and are just as overwritable. If two people (or two agent sessions) need different GCP identities on one machine at the same time, each must export its own `CLOUDSDK_CONFIG=<dir>` before authenticating — that is the only mechanism that gives a fully separate ADC file and account list. `CLOUDSDK_CORE_ACCOUNT`/`CLOUDSDK_CORE_PROJECT` env vars scope which identity a *script's* own `gcloud`/`kubectl` calls use (useful for pinning a module's `null_resource` provisioners), but they do **not** touch ADC, which is what the `google` Terraform provider reads.

**`CLOUDSDK_CONFIG` isolates `gcloud` and its own subprocess calls — it does not isolate OpenTofu/Terraform's ADC lookup.** The `google`/`google-beta` provider is built on the Go `golang.org/x/oauth2/google` package, which resolves Application Default Credentials from `GOOGLE_APPLICATION_CREDENTIALS` if set, otherwise a **hardcoded** `~/.config/gcloud/application_default_credentials.json` — it never reads `CLOUDSDK_CONFIG`. (Python/Node Google auth libraries, including `gcloud` itself, do honor `CLOUDSDK_CONFIG`; the Go one is the outlier.) Confirmed live: with `CLOUDSDK_CONFIG` pointed at an isolated directory and a fresh `gcloud auth application-default login` completed inside it, `tofu plan` still failed with `the user does not have permission to access Project "..." or it may not exist` — it was silently reading a *different, stale* ADC file from a prior session at the hardcoded default path, for an entirely different qwiklabs account and project. Fix: also export `GOOGLE_APPLICATION_CREDENTIALS="$CLOUDSDK_CONFIG/application_default_credentials.json"` before running any `tofu`/`terraform` command against an isolated identity — `CLOUDSDK_CONFIG` alone is not enough; without it, `apply` silently falls back to whatever the shared default ADC currently holds, which may be a different session's identity entirely.

## Architecture

### Module Families

Eight independent modules under `modules/`. No shared foundation module, no symlinks, no cross-module Terraform dependency — each owns every resource it provisions and its own state.

| Module | What it deploys |
|---|---|
| `Istio_GKE` | GKE Standard + open-source Istio (sidecar **or** ambient) + Prometheus/Jaeger/Grafana/Kiali |
| `Bank_GKE` | GKE (Autopilot/Standard) + Cloud Service Mesh + Bank of Anthos + optional ACM + Cloud Monitoring SLOs |
| `MC_Bank_GKE` | Multi-cluster GKE across regions + fleet-wide CSM + Multi-Cluster Ingress/Services + Bank of Anthos |
| `AKS_GKE` | Azure AKS registered in a GKE Fleet as a GKE Attached Cluster via Helm |
| `EKS_GKE` | AWS EKS registered in a GKE Fleet as a GKE Attached Cluster via Helm |
| `VMware_Engine` | GCVE private cloud + VPC peering + Windows jump host + vCenter credential reset |
| `Container_Migration` | GKE cluster + Compute Engine VMs (PostgreSQL source, Tomcat source, M2C workstation) for a Migrate to Containers (M2C) lab |
| `Migration_Center` | Windows Server VM (MCDCv6) + Debian Linux target VMs + Migration Center service registration + optional AWS asset import |

### Standard Module File Layout

```
modules/<Module_Name>/
├── main.tf              # data.google_project, random_id, google_project_service API enablement
├── provider-auth.tf     # google provider with SA impersonation (GKE modules)
├── versions.tf          # required_providers + required_version
├── variables.tf         # UIMeta-annotated inputs
├── outputs.tf           # deployment_id, project_id, cluster_credentials_cmd, external_ip
├── network.tf           # VPC, subnets, Cloud Router + NAT
├── gke.tf               # GKE cluster, node pool, cluster SA, IAM
├── <feature>.tf         # e.g. istiosidecar.tf, istioambient.tf, asm.tf, deploy.tf, hub.tf
├── manifests/           # Raw Kubernetes manifests
├── templates/           # Kubernetes manifests rendered via templatefile()
├── tests/               # *.tftest.hcl using mock providers
└── README.md            # Short overview + inputs/outputs tables
```

Lab guides live at `docs/labs/<Module_Name>.md`, **not** inside the module directory.

### Two Provider Auth Patterns

**Impersonation (`provider-auth.tf`)** — used by `Istio_GKE`, `Bank_GKE`, `MC_Bank_GKE`, `VMware_Engine`, `Container_Migration`, `Migration_Center`. Fetches a short-lived access token for `var.resource_creator_identity` (a service account) when that variable is non-empty; otherwise falls back to ADC.

**Direct (`provider.tf`)** — used by `AKS_GKE`, `EKS_GKE`. Configures `azurerm`/`aws`/`helm` providers directly. Azure credentials via `ARM_*` env vars; AWS credentials via `AWS_*` env vars — never hardcode these as defaults.

### Post-Provisioning via `null_resource`

Anything that can't be expressed as a Terraform resource (installing Istio via `istioctl`, applying Bank of Anthos manifests, waiting for a LoadBalancer IP) uses `null_resource` + `local-exec`:

- **Triggers** must capture every variable the destroy provisioner needs (only `self.triggers.*` is available at destroy time).
- **Create provisioner**: `set -eo pipefail`, installs missing CLIs into `$HOME/.local/bin`, runs `gcloud container clusters get-credentials --impersonate-service-account=...`, then does the actual install.
- **Destroy provisioner**: `set +e`, uses `--ignore-not-found` and `|| echo "Warning:..."` — must be best-effort so destroy never blocks on missing resources.

### Async GCP Feature Readiness — Check State, Not Existence

When a `null_resource` waits for a GCP-managed async feature (GKE Hub/Fleet features like
Cloud Service Mesh, MCI, ACM) before continuing, poll the actual status field — never
treat the mere existence of a `membershipStates` entry as "ready." Google creates that
entry in `PROVISIONING` state within seconds of a membership spec update, long before the
managed control plane and its sidecar-injection webhook are actually live.
`MC_Bank_GKE/hub.tf`'s `wait_for_service_mesh` originally checked
`gcloud container fleet mesh describe --format='get(membershipStates)' | grep -c
$CLUSTER_NAME`, which returned success in ~3 seconds; `deploy.tf` then created the Bank of
Anthos namespace and pods immediately, and every pod came up with zero `istio-proxy`
sidecars — Deployments don't retroactively gain a sidecar once the control plane finishes
rolling out later. Fixed by polling
`membershipStates['<membership-path>'].servicemesh.controlPlaneManagement.state` until it
equals `ACTIVE`, matching the pattern `Bank_GKE/asm.tf`'s `wait_for_service_mesh` had all
along. If a live deployment already shows this symptom (namespace labelled with an ASM
revision but pods have no `istio-proxy` container), `kubectl rollout restart
deployment,statefulset -n <namespace>` once the control plane reaches `ACTIVE` forces pod
recreation so the injector can act on them.

### GCP Org Policies Can Restrict Which Regions Are Usable

Some projects — notably ephemeral training/lab projects (e.g. Qwiklabs) — enforce
`constraints/gcp.resourceLocations`, an org policy that allowlists specific
regions/locations. A module's default region can be entirely unusable there: every
regional resource (subnets, routers, NAT, addresses) fails with `Error 412: ... violates
constraint constraints/gcp.resourceLocations ..., conditionNotMet` — not a quota or
permission error, and easy to misdiagnose as one. Check the effective policy before
assuming a default region works: `gcloud org-policies describe
constraints/gcp.resourceLocations --project=<id> --effective` (enable
`orgpolicy.googleapis.com` first if it 403s). `MC_Bank_GKE` assigns clusters to regions
round-robin via `i % length(var.available_regions)` (`variables.tf`), so passing a single
allowed region still creates the full `cluster_size` count of clusters — just co-located
in one region instead of spread across several. This preserves the multi-cluster
fleet/mesh/MCI demo; only the multi-region geo-redundancy story is lost.

### Interrupted or Manual `tofu apply` Can Leave GCP Ahead of Local State

Killing/interrupting `tofu apply` (Ctrl-C, a wrapper script's timeout, a crashed
terminal) does **not** cancel the underlying GCP operation — cluster creation, for
example, keeps running to completion or failure entirely server-side. Confirmed
live: a `tofu apply` creating an Istio_GKE cluster was killed by an external
10-minute process timeout while `google_container_cluster` was still "creating" at
the 37-minute mark; `gcloud container clusters list` immediately afterward showed
the cluster still `PROVISIONING` in GCP, unaffected by the local process dying. If
you must bound how long you wait on a manual `apply`/`destroy`, poll GCP directly
(`gcloud container clusters describe ... --format="value(status)"`) in a loop
instead of imposing a hard kill on the `tofu` process itself — a hard kill only
desyncs your local view, it does not stop the operation.

This desync reproduces the same failure mode `self_heal_orphaned_creates()`
handles automatically in the CI/Cloud Build pipelines (see Deployment Pipelines
below), but **manual/local `tofu apply` has no such self-heal**. After an
interrupted or failed create, check `tofu state list` against
`gcloud container clusters list`/`describe` before doing anything else:
- If the resource is in GCP but *not* in `tofu state list` (its `Create()` never
  reached `SetId()`), either `tofu import` it once it reaches a stable state, or —
  if it landed in `ERROR` (e.g. from a `GCE_STOCKOUT`, see below) — delete it
  directly with `gcloud container clusters delete` (Terraform doesn't know about it,
  so `tofu destroy` won't touch it) and re-`apply`.
- Re-running `apply` without checking first risks a `409 already exists` if GCP
  finished creating the resource, or a conflicting operation error if GCP is still
  mid-create.

### GKE Node Pool Creation and `GCE_STOCKOUT`

`GCE_STOCKOUT` (`Error waiting for creating GKE cluster: ... does not have enough
resources available to fulfill the request`) is a transient regional/zonal capacity
error, not a config or quota problem — but it can recur across different zones on
consecutive retries within the same region, which looks like bad luck but may
reflect a genuine sustained shortage. Two behaviors make it easy to misdiagnose:
- **GKE always provisions a transient "default" node pool as part of cluster
  creation itself**, even when `remove_default_node_pool = true` removes it
  afterward. A stockout during this phase fails the whole `google_container_cluster`
  resource before Terraform ever gets to your own `google_container_node_pool` — the
  error names an instance in GKE's own `default-pool`, not a node pool you defined.
- `Istio_GKE`'s `google_container_node_pool.preemptible_nodes`
  (`modules/Istio_GKE/gke.tf`) sets `node_locations =
  data.google_compute_zones.available_zones.names` — every zone in the region. For a
  *regional* node pool, `node_count` is applied **per zone**, so `node_count = 2`
  with 4 zones actually provisions 8 nodes, not 2, and a stockout in *any single*
  zone fails the entire pool creation. This raises both the node count (cost) and
  the stockout blast radius beyond what the variable suggests.

### UIMeta Variable Annotations

Every `variable` description ends with a `{{UIMeta group=N order=M }}` tag that drives the RAD platform UI. Groups are module-defined UI sections, not a fixed repo-wide numbering — group values 0 through 9 are in use across the 8 modules (e.g. 0=Provider/Metadata, 1=Main, 2=Network in most modules), but higher numbers (5, 7, 8, 9) are used by modules with extra sizing/jump-host/vCenter-credential sections (Bank_GKE, Container_Migration, Migration_Center, VMware_Engine) beyond the canonical Istio_GKE module's 0-4 range. The `updatesafe` flag marks variables that can change without forcing resource replacement. `enable_services` always lives in group 0 order 109.

### API Enablement Invariant

Every `google_project_service` resource must have both:
```hcl
disable_dependent_services = false
disable_on_destroy         = false
```
Multiple independent modules may share the same GCP project — a destroy of one module must never disable APIs that other modules depend on. Do **not** use `lifecycle { prevent_destroy = true }` on these resources (it causes the destroy pipeline to fail with "Instance cannot be destroyed").

### Managed Cloud Service Mesh Invariants

`Bank_GKE` and `MC_Bank_GKE` provision Cloud Service Mesh via `google_gke_hub_feature_membership` with `mesh { management = "MANAGEMENT_AUTOMATIC" }`. Two things follow from that which are easy to get wrong:

- **CSM's version is not a module input.** Google selects it from the cluster's GKE `release_channel` at provision time — there is no Terraform-settable version. A `cloud_service_mesh_version`-style variable is dead code unless it is actually threaded into an `asmcli` invocation; both modules previously had exactly this variable declared and unused, with a stale default. Don't add one back without wiring it to something real.
- **The CSM revision label must be derived from `release_channel`, never hardcoded.** The namespace label `istio.io/rev` selects which control-plane revision injects sidecars: `asm-managed` (REGULAR), `asm-managed-rapid` (RAPID), `asm-managed-stable` (STABLE). A label naming a revision the cluster's channel isn't serving does **not** error — injection is silently skipped, so the app comes up with zero sidecars while `tofu apply` reports success. Both modules compute this once as `local.asm_revision` in `main.tf` and reference it everywhere the label is set (namespace `metadata.labels`, `kubectl label --overwrite`, and — for `MC_Bank_GKE` — the `istio-<revision>` mesh-config ConfigMap name in `templates/configmap.yaml.tpl`). If you add CSM to another module, copy this pattern rather than hardcoding `asm-managed`.
- **`meshconfig.googleapis.com` must be enabled alongside `mesh.googleapis.com`.** `asm.tf`'s `verify_mesh_api_activation` guard polls for both and `exit 1`s after 300s if either is missing — a module that enables only `mesh.googleapis.com` will hard-fail its own mesh gate every time. Confirmed live: `Bank_GKE`'s `default_apis` was missing it while `MC_Bank_GKE`'s always had it.

### `Istio_GKE`'s `deploy_application` Variable Is Dead Code

`variables.tf` declares `deploy_application` (default `true`, described as deploying the
Istio Bookinfo sample app) and it is UIMeta-tagged into the deployment UI, but it is never
referenced anywhere else in the module — no `.tf` file, script, or manifest reads
`var.deploy_application`, and there is no Bookinfo install step at all. Toggling it does
nothing in either direction. `docs/modules/Istio_GKE.md` and `docs/labs/Istio_GKE.md`
already document the real behavior correctly (no demo app is provisioned; deploy Bookinfo
yourself into the pre-labelled `default` namespace) — but `variables.tf`'s own
description string, the module catalog's `module_description`, and this module's
`README.md` did not match until this was caught and corrected. If you wire up the
variable for real, update all of these together; if you remove it, check the RAD platform
UI form definition and any existing deployments' saved tfvars for references first.

## Key Conventions

- Every `.tf` file begins with the Apache 2.0 license header (Google LLC).
- File names: `snake_case` for `.tf` files; module directories are `PascalCase_WithUnderscores`.
- All modules use `project_id` (not `existing_project_id`) and `region` (not `gcp_region`) for GCP inputs.
- `MC_Bank_GKE` uses four static `kubernetes` provider aliases (`cluster1`–`cluster4`); provider configurations must be static in Terraform — they cannot be generated with `for_each`.
- The `Istio_GKE` sidecar installer pipes a custom `IstioOperator` YAML into `istioctl install -y -f -` to set `hpaSpec.scaleTargetRef.name = istio-ingressgateway` — do not remove this block (it prevents known HPA naming conflicts).
- `external_ip` output reads from a file written by post-provisioning `null_resource` and falls back to `"IP not available"` via `fileexists()`.
- State is never stored in the repo — the launcher and `rad-ui` pipelines store it in GCS.
- **Provider version constraints must have an upper bound.** An unbounded `">=X.Y.Z"` lets a fresh `tofu init` silently resolve a new major version and break the module before it ever reaches the cloud provider. Confirmed live: `AKS_GKE`'s `azurerm = ">=3.17.0"` resolved 5.0.1, which made `node_provisioning_profile` a required block on `azurerm_kubernetes_cluster` and failed `tofu validate`/`plan` outright; pinning `"~> 4.0"` (resolving 4.81.0) fixed it with no code change. The same unbounded shape is still present in `EKS_GKE`'s `aws = ">=4.5.0"` and in every module's `google = ">=5.0.0"` (currently resolving 7.43.0, two majors past when most of these modules were written) — treat those as latent, not merely theoretical. Lock files (`.terraform.lock.hcl`) are gitignored repo-wide, so the `~>` constraint in `versions.tf`/`provider.tf` is the *only* thing preventing this in CI and on the Cloud Build pipelines, which both run a fresh `init`.

## CI Pipeline

The GitHub Actions workflow (`.github/workflows/terraform-ci.yml`) runs on changes to `modules/**`:

1. **format** — `terraform fmt -check -recursive modules/`
2. **validate** — `terraform init -backend=false && terraform validate` per changed module
3. **tflint** — Google ruleset via `.tflint.hcl`
4. **test** — `terraform test` per module (mock providers, no GCP credentials)
5. **security** — Trivy config scan (HIGH/CRITICAL, non-blocking)

CI uses `terraform` (Terraform ~1.9) not `tofu`, but they are interchangeable for `init`/`validate`/`fmt`/`test`.

## Deployment Pipelines (`rad-ui/automation/`)

The RAD platform's Cloud Build pipelines live here, not just the module catalog:
`cloudbuild_deployment_{create,update,destroy,purge}.yaml`. They are driven by
Cloud Build triggers that read the YAML from `main` at trigger time
(`git_file_source` in `rad-automation`'s `cloudbuild.tf`), so a merge to `main`
takes effect on the next run — there is no separate deploy step.

**A Cloud Build step's inline script is capped at 10,000 characters, and exceeding
it means the build never starts.** The failure is `invalid build: invalid .steps
field: build step 0 arg 1 too long (max: 10000)` — not a step failure, so there is
no step output to read and the message names nothing you were working on. Adding an
explanatory comment block to the destroy pipeline's first step took it to 10,164 and
broke every destroy on the platform until trimmed. Run
`python3 rad-ui/automation/check_step_arg_limits.py` after touching any
`cloudbuild_*.yaml`; it fails over the limit and warns above 9,000. **This is now also
enforced automatically** by `.github/workflows/cloudbuild-lint.yml` on any push/PR
touching `cloudbuild*.yaml` or the checker itself — a red CI check on this workflow
means one of the limits below was crossed, not a real pipeline bug. The largest
steps already sit at 8–9k, so the margin is thinner than it looks.

**The real fix for a step approaching the limit is to extract its script to a file
under `rad-ui/automation/scripts/`, not to trim comments.** The create, update, and
destroy pipelines' Apply/prepare steps now live in
`scripts/apply_infrastructure.sh`, `scripts/apply_infrastructure_update.sh`, and
`scripts/prepare_destroy.sh` respectively — the YAML step just stages and sources
the script. (The destroy pipeline's separate `Destroy Infrastructure` step, holding
`DESTROY_MAX_ATTEMPTS` and the GKE state-repair logic below, is still inline —
extraction is per-step, not all-or-nothing per pipeline.) `check_step_arg_limits.py`
also enforces a **second, unrelated rule**: any Cloud Build `volumes:` name must be
used by two or more steps, or the build is rejected outright
(`invalid build: Volume "X" is used only once, need twice or more`) — the shared
`pipeline-scripts` volume that stages extracted scripts must be mounted by both the
staging step and every step that sources from it, or this fires. Confirmed live
2026-08-06: an extraction that staged the script but only referenced the volume in
one step broke every destroy in production (7 failed deployments) until fixed.

**An invalid build produces no logs.** `gcloud builds log <id>` shows nothing;
the reason is in `statusDetail` on the build record — use
`gcloud builds describe <id> --format="value(status,statusDetail)"`.

**Create/update applies self-heal an orphaned resource instead of failing outright
on a flaky creation-wait.** `self_heal_orphaned_creates()` (in the extracted apply
scripts) triggers on `Error waiting for (creating|Create)`: the Terraform provider's
`Create()` doesn't call `SetId()` until its own wait-for-ready poll succeeds, so a
resource that was genuinely created in GCP but whose poll flaked leaves state with
no entry for it — the next apply then tries to create it again and hits `409 already
exists`. The self-heal `tofu import`s any planned-create
`google_sql_database_instance`/`google_container_cluster`/`google_storage_bucket` by
its live resource ID, re-plans, and retries the apply once if anything imported.
Scoped to those three resource types only — a different resource type failing the
same way still needs a manual `tofu import`.

**Purge no longer deletes the GCS deployment folder outright.** `cloudbuild_deployment_purge.yaml`
now reports the folder's size/file count and **retains** the Terraform state and
deployment files instead of `gsutil -m rm -r`-ing them — actual deletion moved to
`rad-automation`'s `deployment_cleanup` Phase 3, which runs after a soft-delete grace
period. This changes what "purge" means operationally: it no longer immediately frees
the GCS prefix, and a purge followed immediately by a re-deploy to the same
deployment ID will still find the old state/files present.

**The destroy pipeline decides "nothing to destroy" from state CONTENTS, never file
existence.** `backend.tf` and an empty state object are both written during
preparation, before anything is applied, so their presence proves nothing — an
earlier guard keyed on `backend.tf` refused a deployment whose state held
`serial: 1, resources: []`. It now derives the state path from `backend.tf`'s own
bucket/prefix and counts `.resources`: unreadable → refuse, 0 or absent → skip
Terraform and run the GCS cleanup, 1+ → refuse and name the orphaning risk.

**Destroy runs ONE attempt by default (`DESTROY_MAX_ATTEMPTS`, default 1) — do not
raise it to wait out a blocked destroy.** GCP frees Direct VPC Egress's
`serverless-ipv4-*` addresses 20–30 minutes after the owning Cloud Run services are
deleted, and a previous 6-attempt/300s-backoff budget sized to outlast that window
could not: one real destroy burned 39m3s of billed build time and still failed. Build
minutes cost money; an operator re-running the delete once the addresses have drained
does not. On that error signature the failure now names the cause and the wait.
The **GKE state repair is deliberately exempt** from the budget — when
`google_container_cluster` is destroyed before `kubernetes_namespace_v1`, the
provider falls back to `localhost:80` and every `kubernetes_*` destroy fails
`connection refused` *permanently*, so re-running would loop forever; it repairs
state and retries once, waiting for nothing. Fail-fast is right for what time fixes,
wrong for corrupted state.

## Standalone Lab Scripts (`scripts/gcp-istio-*`)

`scripts/gcp-istio-traffic/gcp-istio-traffic.sh` and
`scripts/gcp-istio-security/gcp-istio-security.sh` are menu-driven bash demos
of Istio, independent of `modules/Istio_GKE` — neither is invoked by the
module. Both share a `MODE` (preview/create/delete, set once via option `0`)
and a `.env` file re-sourced at the top of every step. See `SKILLS.md` §10 for
the full pattern; the traps below are easy to reintroduce when editing either
script.

**`.env` is rewritten wholesale, not appended to, at several points** — the
initial bootstrap before the menu loop starts, and inside option `0`'s
create/delete branches (once per script). A new persisted variable
(`ISTIO_MODE` is the current example) must be added to **every** one of those
`cat <<EOF > $PROJDIR/.env` heredocs, pinned to its current value
(`${ISTIO_MODE:-sidecar}`), or the next time a user re-runs option `0` — a
normal, README-documented action for switching projects — the rewrite
silently drops it back to unset.

**Steps that reset the namespace to hand the next step a clean slate must
reapply the active mode, not a hardcoded one.** `gcp-istio-security.sh`'s
steps `6` and `8` both delete-and-recreate `$APPLICATION_NAMESPACE` at their
end. Before ambient mode existed this could hardcode
`istio-injection=enabled` safely; now it must branch on `$ISTIO_MODE` and, for
ambient, redeploy the waypoint (`istioctl waypoint apply`) — the namespace
recreate destroys it too, since it's namespaced. Get this wrong and ambient
mode silently reverts to sidecar with no error.

**Gateway API cannot express everything the legacy Istio API can.** Both
scripts use Gateway API (`Gateway`/`HTTPRoute`) for ingress and traffic
mirroring — `HTTPRoute` has a native `RequestMirror` filter and can attach
directly to a `Service` via `parentRefs` for east-west routing with no
`Gateway` needed. But `HTTPRoute.backendRefs` point at distinct Services, not
`DestinationRule`-style label subsets, and there is **no Gateway API
equivalent for fault injection** (upstream declined to add one:
istio/istio#54196) **or circuit breaking**. Subset/version routing, fault
injection, circuit breaking, and egress TLS stay on
`VirtualService`/`DestinationRule` in both scripts — do not try to force
these onto Gateway API.

**Ambient mode `AuthorizationPolicy` L7 rules fail closed, not open, when
attached with `selector`.** ztunnel is L4-only; any L7 rule (method/path
match) needs both a waypoint proxy deployed for the destination *and* the
policy attached via `targetRefs` pointing at a `Service`/`Gateway` rather
than a workload `selector`. A `selector`-attached L7 policy under ambient
silently becomes deny-everything — `kubectl get authorizationpolicy` gives no
hint anything is wrong. `gcp-istio-security.sh` step `8`'s examples are
`selector`-based and correct for their own always-sidecar namespaces; step
`9` exists specifically to demonstrate this failure and the `targetRefs` fix
side by side.

**`ISTIO_VERSION` has no single source of truth.** `modules/Istio_GKE`'s
`istio_version` Terraform variable default and each script's hardcoded
`ISTIO_VERSION` in its `.env` bootstrap are three independent values. This
repo has already shipped the drift once — the module moved off an EOL Istio
version while both scripts stayed behind until a follow-up commit synced
them. When bumping the default Istio version, grep for `ISTIO_VERSION=` and
`istio_version` across `modules/`, `scripts/`, and `docs/` and update every
hit.

## Working in This Repo with Claude Code

**The `Edit`/`Write` pre-tool-use secret-scanning hook (`.claude/hooks/scan_secrets.py`)
resolves its own script path relative to the shell's current working directory, not the
repo root.** If a prior `Bash` command `cd`'d into a module directory (e.g.
`modules/Istio_GKE`) and that directory persists as the shell's cwd, the next `Edit` call
fails with `can't open file '.../modules/Istio_GKE/.claude/hooks/scan_secrets.py': [Errno
2] No such file or directory` — the hook is looking for itself under the wrong directory.
Fix: run `cd <repo-root>` (or use a subshell — `(cd modules/X && ...)` — for the `tofu`
commands instead of a bare `cd`) so the shell's cwd is back at the repo root before the
next `Edit`/`Write` call.

## Agent Workflows

`AGENTS.md` defines slash-command workflows to context-switch into specific module modes: `/istio`, `/bank`, `/multicluster`, `/attached`, `/troubleshoot`, `/maintain`, `/security`. Read `SKILLS.md` for the detailed implementation guide before making structural changes to any module.
