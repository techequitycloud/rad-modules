Guided deployment and test campaign for one or more rad-modules modules: $ARGUMENTS

$ARGUMENTS is a comma/space-separated list of module names (e.g. "Istio_GKE", "Bank_GKE
EKS_GKE"). If empty, include every deployable module under `modules/`.

Deployments go through `rad-launcher` (`rad-launcher/radlab.py`), which stores Terraform
state in a GCS bucket — state is never kept in the repo.

---

**PHASE 1 — CONFIGURE**

Resolve campaign parameters from the environment, prompting for anything missing:

```bash
export PROJECT_ID="${RAD_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
export STATE_BUCKET="${RAD_STATE_BUCKET:-${PROJECT_ID}-radlab-tfstate}"
export RESOURCE_CREATOR_IDENTITY="${RESOURCE_CREATOR_IDENTITY:-}"
```

Display the resolved values and confirm before continuing:

```
Campaign parameters
  Project:       $PROJECT_ID
  State bucket:  $STATE_BUCKET   (must exist; create with: gcloud storage buckets create gs://$STATE_BUCKET)
  Creator SA:    $RESOURCE_CREATOR_IDENTITY (blank = caller ADC)
```

Confirm prerequisites are installed once: `python3 rad-launcher/installer_prereq.py`.

---

**PHASE 2 — RESOLVE MODULE LIST**

Scan `modules/` for deployable directories (has main.tf/variables.tf). Apply the $ARGUMENTS
filter; report "Unknown module: <name>" for any token without a directory.

For each selected module, read variables.tf for REQUIRED inputs (declared type, no default)
beyond the standard set, and for any cloud credentials it needs:
  - AKS_GKE: Azure `client_id`, `client_secret`, `tenant_id`, `subscription_id` (via tfvars
    or `ARM_*` env vars — never hardcode).
  - EKS_GKE / Migration_Center: AWS `aws_access_key` / `aws_secret_key` (via tfvars or
    `AWS_*` env vars).
For each module, prepare a minimal tfvars file capturing project_id, deployment_id (optional),
and any required inputs. Report any input you cannot fill so the user can supply it.

---

**PHASE 3 — DEPLOY (one module at a time)**

Deploy modules SERIALLY — each GKE-based module provisions a cluster and post-provisioning
installers; running several at once contends on cluster operations. For each module:

```bash
python3 rad-launcher/radlab.py \
  -m <Module> -a create \
  -p "$PROJECT_ID" -b "$STATE_BUCKET" \
  -f /path/to/<module>.tfvars
```

Stream the output. On failure, capture the error, classify it (auth/quota/API/timeout vs a
real module bug), and report — do not silently retry destructive operations.

---

**PHASE 4 — VERIFY**

After a successful create, sanity-check the deployment:
  - Read the module outputs (`deployment_id`, `project_id`, and any endpoint output).
  - For GKE modules, fetch credentials and confirm core workloads are Ready
    (`kubectl get pods -A`), e.g. Bank of Anthos frontend, Istio ingressgateway.
  - For an exposed endpoint, curl the ingress IP for an HTTP 200 where applicable.
Record PASS/FAIL per module with the evidence (the failing pod, the HTTP status).

---

**PHASE 5 — DESTROY (if this is a create→destroy test)**

```bash
python3 rad-launcher/radlab.py \
  -m <Module> -a destroy \
  -p "$PROJECT_ID" -b "$STATE_BUCKET" \
  -f /path/to/<module>.tfvars
```

Confirm destroy completes cleanly (best-effort destroy provisioners may print warnings — that
is expected). Verify no orphaned clusters/networks remain.

---

**REPORT**

Per module: deploy result, verify result (with evidence), destroy result, and any bug found
with a concrete fix suggestion. Summarise as a table at the end.
