---
name: services-gcp-deploy
description: Deploy the partner-modules Services_GCP platform module to a GCP project with Cloud SQL (Postgres/MySQL), GKE, and shared infrastructure — including state management when switching projects.
source: auto-skill
extracted_at: '2026-07-13T09:14:27Z'
---

# Services_GCP Deployment

## Purpose

Deploy the `Services_GCP` platform module from the `partner-modules` repository.
This module provisions the shared infrastructure layer (VPC, Cloud SQL, GKE,
Artifact Registry, NFS, service accounts) that application modules depend on.

## Prerequisites

- GCloud isolated auth set up for the target project (see `gcloud-isolated-auth` skill)
- `partner-modules` repository checked out at the same workspace root as `rad-modules`
- `tofu` (OpenTofu) available on PATH

## Procedure

### Step 1: Handle stale state

The Services_GCP module directory accumulates state from prior projects.
Before deploying to a new project, check:

```bash
cd partner-modules/modules/Services_GCP
ls -la terraform.tfstate*
```

If the current `terraform.tfstate` is for a **different project**, park it:

```bash
mv terraform.tfstate "terraform.tfstate.parked-<old-project>-$(date +%Y%m%d)"
mv terraform.tfstate.backup "terraform.tfstate.backup.parked-<old-project>-$(date +%Y%m%d)"
```

Then clear any stale lock and plans:

```bash
rm -f .terraform.tfstate.lock.info plan.tfplan plan-output.tfplan
```

### Step 2: Write a minimal `config/deploy.tfvars`

```hcl
resource_creator_identity = ""
project_id                = "<target-project-id>"
tenant_deployment_id      = "demo"

module_dependency = []   # platform is root of stack

# Databases
create_postgres = true
create_mysql    = true

# GKE
create_google_kubernetes_engine = true
```

Key points:
- `resource_creator_identity = ""` — use caller identity (no SA impersonation).
  Only set it to an SA email when deploying via the RAD platform Cloud Build,
  which needs to impersonate.
- `tenant_deployment_id` — short prefix applied to all resource names.
  Must be `[a-z0-9]+` only. Every app module deployed on top must use the
  **same** tenant ID.
- `module_dependency = []` — Services_GCP is the root module; it has no
  upstream.

### Step 3: Initialize & validate

```bash
GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token 2>/dev/null)" \
  tofu init -reconfigure -upgrade -input=false

GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token 2>/dev/null)" \
  tofu validate
```

### Step 4: Plan

```bash
GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token 2>/dev/null)" \
  tofu plan -input=false -no-color -var-file=config/deploy.tfvars -out=plan.tfplan
```

Check the `Plan: N to add` line — expect **170-180 resources** for a fresh
deploy with Postgres + MySQL + GKE.

### Step 5: Apply (background — takes 30-35 min)

The apply is long (Cloud SQL dominates, plus GKE addon enablement serializes).
Run as a background task:

```bash
GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token 2>/dev/null)" \
  tofu apply -input=false -no-color plan.tfplan &
```

Monitor with:
```bash
tail -f <output-file>
```

Set up a loop wakeup every 5 minutes to check progress.

**Resource provisioning order and timing:**

| Phase | Resources | Typical duration |
|---|---|---|
| 1. APIs & SAs | Service enablement, IAM SAs | 1-2 min |
| 2. Network | VPC, subnets, firewall, Cloud Router+NAT | 1-2 min |
| 3. API wait | `time_sleep.wait_for_apis` (360s) | 6 min |
| 4. Service networking | `google_service_networking_connection` | ~1 min |
| 5. Cloud SQL Postgres | `POSTGRES_17` instance | 5-7 min |
| 6. GKE Autopilot | Cluster `gke-cluster-1-{tenant}{hash}` | 7-10 min |
| 7. Cloud SQL MySQL | `MYSQL_8_4` instance (parallel with GKE) | 5-7 min |
| 8. GKE addons | Secret Manager + Secret Sync (serialized!) | 2-17 min |
| 9. NFS & remaining | NFS MIG, IAM bindings, outputs | 1-2 min |

**The GKE addons step (phase 8) can dominate total time.** The
`null_resource.configure_gke_addons` runs two sequential `gcloud container
clusters update` commands:
1. `--enable-secret-manager` — completes in ~1-2 min
2. `--enable-secret-sync` (beta) — retries up to 30 times with 30s sleeps
   while the cluster processes the first update. At worst this adds **15
   extra minutes**. The retry loop gracefully warns and continues if the
   cluster stays busy past all attempts — `App_GKE` will enable secret-sync
   itself if needed, so this failure is non-blocking.

### Step 6: Verify

After apply completes, confirm the platform is ready:

```bash
gcloud compute networks list --project=$P --format='value(name)'
gcloud container clusters list --project=$P --region=$R --format='value(name,status)'
gcloud sql instances list --project=$P --format='value(name,state,databaseVersion)'
```

Expected: VPC present, GKE cluster `RUNNING`, both SQL instances `RUNNABLE`.

## What gets created (with Postgres + MySQL + GKE)

| Component | Details |
|---|---|
| VPC | `vpc-network-{tenant}{hash}` with subnet, Cloud Router + NAT, firewall |
| Cloud SQL Postgres | `POSTGRES_17`, private IP, 1vCPU/3.84GB, 10GB SSD |
| Cloud SQL MySQL | `MYSQL_8_4`, private IP, 1vCPU/3.84GB, 10GB SSD |
| GKE | Autopilot cluster `gke-cluster-1-{tenant}{hash}` |
| Artifact Registry | Docker repo `shared-repo-{tenant}{hash}` |
| Service Accounts | Cloud Build, Cloud Run, GKE, Cloud Deploy, NFS |
| NFS | Self-managed NFS server (MIG, converges async after apply) |
| Secrets | DB root passwords in Secret Manager |

## Common failure modes

- **Stale state pointing at wrong project** → terraform tries to reconcile
  foreign infra → park state and start fresh.
- **`GOOGLE_OAUTH_ACCESS_TOKEN` expired mid-apply** → 401 error → re-export
  token and re-apply.
- **NFS VM stuck in zone stockout** → `ZONE_RESOURCE_POOL_EXHAUSTED` →
  repin MIG to a different zone in `nfs.tf` and re-apply.
- **Missing ADC** → tofu fails with project-permission error even though
  `gcloud` works → export `GOOGLE_OAUTH_ACCESS_TOKEN`.
- **Region org-policy** (Qwiklabs pins `us-west1`) → set
  `availability_regions = ["us-west1"]` in tfvars.
