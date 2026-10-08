# Multi-Cluster Bank of Anthos on GKE

<img src="https://storage.googleapis.com/rad-public-2b65/modules/MC_Bank_GKE.png" alt="Multi-Cluster Bank of Anthos on GKE" style={{maxWidth: "100%", borderRadius: "8px"}} />

This module deploys **Bank of Anthos** — Google's open-source microservices banking demo — across **multiple GKE clusters in multiple regions**, wired together as a single application platform. It is a self-contained, standalone module: it builds its own VPC, creates every GKE cluster, registers them all into a **GKE Fleet**, joins them into one **multi-primary Cloud Service Mesh**, and fronts them with a **multi-cluster gateway / global external load balancer** so a single public address serves the nearest healthy region.

It is intended as an educational reference for the active-active, geo-redundant architecture that regulated financial and global payment platforms use to meet high-availability and data-residency requirements. It is not a production banking system.

This guide focuses on the Google Cloud services the module exercises and how to explore and operate them from the Cloud Console and the command line — with particular attention to working **across more than one cluster at once**.

---

## What Bank of Anthos costs on RAD, and how that compares

**Multi-Cluster Bank of Anthos on RAD's GKE module costs about US$24 a month in your own project, and RAD charges no module fee for it at all.** Bank of Anthos has no module fee — you pay only Google's infrastructure cost and a few credits of build time. If you only need it occasionally, a RAD-managed project can be deleted and restored within 30 days for a few credits, so that monthly figure becomes a few dollars instead — see **Pause it for free**, below.


### What you pay on RAD

| | In a Google Cloud project you own | In a project RAD manages for you |
|---|---|---|
| Module fee, once per deployment | Free (0 credits) | Free (0 credits) |
| Build time | A few credits per build | The same |
| Google Cloud running cost | Billed by Google to your own billing account, about **US$24 a month** for the default configuration (table below) | Metered hourly in credits; RAD publishes **43 credits a day**, about 1,290 a month (about US$129.00 at the top-up price, less on a plan) |
| Who owns what | You own the project and its billing; RAD deploys and updates it | RAD owns the project, with guardrails, quotas and budget alerts; you get console access, and a minimum purchased balance is held in reserve |

10 credits cost US$1 on a one-off top-up, and less on a monthly plan. In a project RAD manages, the database, file server and network are shared by every application in the project, so a second application does not add a second database.

**Default running cost in your own project** (us-central1, Google list prices):

| Resource (module default) | Per month |
|---|---|
| GKE Autopilot pod, 0.5x vCPU / 0.5 GiB | US$18 |
| Cloud NAT and networking | US$5 |
| Cloud Storage (add-ons, backups) | US$1 |
| GKE cluster management fee | shared across every GKE app in the project; US$0 if this is your only cluster, else ~US$73 |
| **Total** | **about US$24** |

### How it compares

- Bank of Anthos is Google's own open-source **reference architecture** for an
  active-active, geo-redundant banking platform — it is not a commercial product, and there is
  no SaaS equivalent to price against.
- The honest comparison is **operational complexity, not a monthly bill**: replicating what
  this module automates — multiple GKE clusters across regions, a Fleet, a multi-primary
  service mesh and a multi-cluster gateway — by hand requires genuine multi-cluster Kubernetes
  and cross-region networking expertise. A single VPS (even a well-specced one) cannot stand
  in for that architecture, which is the point of running it here rather than on one box.
- RAD's cost is about US$24 a month in your own project **with no module fee at
  all** — this module exists to teach the pattern, not to sell a deployment, so RAD does not
  charge for it beyond Google's own infrastructure cost and the builds.


### Pause it for free: delete a RAD-managed project, restore it when you need it

If Bank of Anthos runs in **a project RAD manages for you**, you have a second option that goes
well beyond scaling to zero: **delete the whole project, and restore it within 30 days for
close to nothing.** This suits Bank of Anthos you only need occasionally — evaluating it, a demo
environment, a seasonal or intermittent workload — far better than running it continuously.

- **How it works.** Deleting a RAD-managed project unlinks its billing first, then asks Google
  to delete the project. Google does not remove the project immediately: it keeps it,
  recoverable, for 30 days. Because billing is already unlinked, nothing is charged while it
  waits. Unlike deleting one module, this does not tear down the database, any VM or the
  compute resource one by one — the whole project, and everything in it, simply stops.
- **Restoring costs a few credits, not a rebuild.** Within 30 days, the project's owner can
  restore it. RAD asks Google to undelete the project and reattaches its billing account, then
  asks you to run **Update** on each deployment to confirm everything came back. Because
  nothing was individually destroyed, that Update finds the same resources already there — it
  is a check, not a rebuild, and an Update never charges the module fee again. For Bank of Anthos that is roughly **5 credits (under US$1)**, the same as a full redeploy, because there is no module fee to begin with.
- **So a month of occasional use can cost a few dollars, not US$24.**
  Deploy Bank of Anthos, use it for a while, delete the project. Restore it next time you need it,
  confirm with Update, and delete it again when you're done. You pay only for the module fee
  once, the builds, and whatever time it was actually live.
- **What this needs.** You must own the project (not one RAD only manages billing for), and
  you restore it yourself within the 30 days — after that, Google deletes it for good.
  Restoring is admitted like creating a new project: your purchased credit balance must still
  clear the tier's floor (100 credits for the sandbox tier most evaluation use fits). Google
  says most services are fully working again within 36 hours of a restore.
- **One real gap: nightly backups do not survive.** Backups and other generated files are
  written to a bucket inside the project, and that bucket is **not** protected by Cloud
  Storage's soft-delete, so it is very likely gone as soon as you delete the project — even
  though the project itself is recoverable for 30 days. If you have customised Bank of Anthos and
  want to keep that work, copy a backup out (to Google Drive, or a bucket outside the project)
  before you delete. For a default installation with nothing irreplaceable in it, this does
  not matter.


### Pay only while you use it, the other way: delete and redeploy

The option above only applies to a RAD-managed project; **in your own project, or once the
30-day window has passed, the way to stop paying is to delete the deployment and deploy it
again when you need it.**

- **What a redeploy costs.** The module fee again, plus the builds — roughly
  5 credits (US$0.50) in total. Deleting saves money
  only once Bank of Anthos would otherwise sit unused long enough to clear that redeploy cost
  against its own running cost — about **1 days or more**, both in your own project
  (about US$0.80 a day) and in a RAD-managed one (43 credits a day).
- **Most of the running cost is usually shared.** For Bank of Anthos that is the database. They stop only when nothing else in the project uses them, so deleting this app while something else shares the project saves only this app's own compute part.
- **Keep your data first.** Nightly backups go to a bucket inside the deployment and are
  deleted with it, so copy the latest backup out before deleting if you want to keep it.


### Lab sessions and Managed Environments

- **Lab sessions, for training.** A trainer runs a session for a class. Each participant gets
  the app in their own Google Cloud project for 15 minutes to 24 hours, within an allowance the
  trainer sets. Either the trainer funds every place, or each participant pays for their own.
  Everything is deleted when the session ends and unused credits go back to the trainer.
- **Managed Environments, for consultancies.** A partner runs the app for a client from a
  ring-fenced wallet it funds, and settles with the client directly. If the wallet runs low,
  billing pauses and the data is kept, so nobody receives an unexpected charge. At the end the
  partner hands the project over and the deployments become the client's own.

Credits can be bought in more than 20 currencies, including XAF, XOF, NGN, GHS, KES and ZAR, by
card, bank transfer or mobile money.


**Sources (8 October 2026):** Google Cloud list prices from the Cloud Billing Catalog API; RAD fees and the daily-credit estimate from [radmodules.dev/pricing](https://radmodules.dev/pricing); [Delete and restore projects](https://cloud.google.com/resource-manager/docs/delete-restore-projects) for the pause/restore mechanics and what it says about Cloud Storage objects without soft delete. Prices change; check each source before relying on a figure.


## 1. Overview

The module stands up an entire multi-cluster platform from nothing and then deploys the banking application onto it:

| Capability | Google Cloud service | Notes |
|---|---|---|
| Compute | GKE Autopilot (Standard optional) | One cluster per region; `cluster_size` clusters, default 2 |
| Multi-cluster management | GKE Fleet (Hub) | Every cluster registered as a Fleet membership |
| Service mesh | Cloud Service Mesh (managed Istio) | Multi-primary, enabled fleet-wide in automatic-management mode |
| Cross-cluster discovery | Multi-Cluster Services (MCS) | Fleet feature for cross-cluster service backends |
| Global ingress | Multi-Cluster Ingress + global external Application Load Balancer | One anycast IP routes to the nearest healthy cluster |
| TLS | Google-managed certificate | Auto-provisioned for an `sslip.io` domain derived from the global IP |
| Networking | Shared VPC, per-cluster subnets, Cloud Router + Cloud NAT, firewall rules | Global-routing VPC; a Cloud Router + Cloud NAT per cluster region. Clusters are **not** private — the module declares no `private_cluster_config`, so nodes and the control-plane endpoint use GKE's default public configuration |
| Observability | Cloud Logging, Cloud Monitoring, Managed Service for Prometheus, Cloud Trace | Aggregated across the whole fleet |
| Application | Bank of Anthos (v0.6.10) | 9 microservices (Python + Java) plus two in-cluster PostgreSQL databases |

**Things to know up front:**

- **This is genuinely multi-cluster.** `cluster_size` (default `2`) clusters are created and each is placed in a region from `available_regions` in round-robin order. With the defaults you get two clusters: `gke-cluster-1` in `us-west1` and `gke-cluster-2` in `us-east1`. Adding more regions or raising `cluster_size` spreads further (e.g. 2 regions + 4 clusters cycles `us-west1`, `us-east1`, `us-west1`, `us-east1`).
- **Cluster names are 1-indexed** — `gke-cluster-1`, `gke-cluster-2`, …, `gke-cluster-N`. `cluster1` is always the **primary / config cluster** in `available_regions[0]`.
- **The databases live on the primary cluster only.** The `accounts-db` and `ledger-db` PostgreSQL StatefulSets are deployed only on `gke-cluster-1`. Non-primary clusters run the stateless services plus the database *Services* and *ConfigMaps*, but not the database pods — they are designed to reach the primary cluster's databases through the fleet. Losing the primary cluster takes the data tier offline.
- **One global IP, one domain.** A single global address is reserved and the app is published at `https://boa.<GLOBAL_IP>.sslip.io`, with TLS issued automatically. `sslip.io` resolves any `<ip>.sslip.io` name to that IP, so no DNS zone is required.
- **The mesh is multi-primary.** Cloud Service Mesh is enabled at the fleet level with automatic management; every cluster runs a managed control plane and shares one trust domain (`<project>.svc.id.goog`), so sidecars in any cluster mutually authenticate.
- **No Cloud SQL, Memorystore, or Secret Manager are used by the app.** Bank of Anthos runs its own in-cluster PostgreSQL and a Kubernetes-Secret JWT key pair. (Some related project APIs are enabled, but the application does not depend on those managed services.)
- **First deploy is long.** Creating multiple clusters, registering the fleet, provisioning the managed mesh, and bringing up the global load balancer with a managed certificate typically takes **40–60 minutes**.

---

## 2. Google Cloud Services & How to Explore Them

Because this is a multi-cluster deployment, most exploration involves **switching between cluster contexts**. Set up one context per cluster and reuse them throughout:

```bash
export PROJECT="<your-project-id>"
export REGION1="us-west1"   # available_regions[0] — primary/config cluster
export REGION2="us-east1"   # available_regions[1]

gcloud container clusters get-credentials gke-cluster-1 --region "$REGION1" --project "$PROJECT"
gcloud container clusters get-credentials gke-cluster-2 --region "$REGION2" --project "$PROJECT"

# Friendlier context aliases
kubectl config rename-context "gke_${PROJECT}_${REGION1}_gke-cluster-1" cluster1
kubectl config rename-context "gke_${PROJECT}_${REGION2}_gke-cluster-2" cluster2
kubectl config get-contexts
```

The application namespace is `bank-of-anthos` on every cluster.

### A. GKE clusters — the compute fabric

Each cluster runs the banking workloads on Autopilot (Standard is optional). Clusters are VPC-native, enrolled in the chosen release channel, and have GKE Security Posture, Managed Prometheus, the GCS FUSE CSI driver, Gateway API, and cost management enabled.

- **Console:** Kubernetes Engine → Clusters lists every cluster with its mode, region, version, and node count.
- **CLI:**
  ```bash
  gcloud container clusters list --project "$PROJECT" \
    --format="table(name,location,autopilot.enabled,currentMasterVersion,status)"
  kubectl --context cluster1 get nodes -o wide
  kubectl --context cluster2 get nodes -o wide
  ```

### B. GKE Fleet (Hub)

Every cluster is registered as a Fleet membership (membership ID = cluster name) under a single project-level fleet. The fleet is what makes the mesh, MCS, and Multi-Cluster Ingress span clusters.

- **Console:** Kubernetes Engine → Fleets shows all memberships and which fleet features are enabled per cluster.
- **CLI:**
  ```bash
  gcloud container fleet memberships list --project "$PROJECT"
  gcloud container fleet features list --project "$PROJECT"
  ```

### C. Multi-Cluster Services (MCS)

MCS is enabled as a fleet feature so services can have backends across clusters. The frontend is published fleet-wide through a `MultiClusterService` (`bank-of-anthos-mcs`) on the config cluster.

- **Console:** Kubernetes Engine → Services & Ingress (on the config cluster) shows the multi-cluster Service.
- **CLI:**
  ```bash
  kubectl --context cluster1 get multiclusterservice -n bank-of-anthos
  kubectl --context cluster1 describe multiclusterservice bank-of-anthos-mcs -n bank-of-anthos
  # The MCS importer runs in the gke-mcs namespace on member clusters:
  kubectl --context cluster2 get pods -n gke-mcs
  ```

### D. Cloud Service Mesh (multi-primary)

The mesh is enabled fleet-wide with automatic management — Google runs the Istio control plane for each cluster. The `bank-of-anthos` namespace carries the CSM revision label matching the cluster's release channel — `istio.io/rev=asm-managed` for `REGULAR`, `-rapid`/`-stable` for the other two — so every pod gets an Envoy sidecar (each app pod shows `2/2` ready). A label naming a revision the channel isn't serving does not error; injection is silently skipped and pods come up with no sidecar. All clusters share one trust domain, so the mesh is multi-primary and traffic between clusters is mutually authenticated.

- **Console:** Kubernetes Engine → Service Mesh shows the combined topology, golden signals, and mTLS status across all clusters.
- **CLI:**
  ```bash
  gcloud container fleet mesh describe --project "$PROJECT"   # per-membership control/data plane state
  # Confirm sidecar injection on each cluster:
  kubectl --context cluster1 get pods -n bank-of-anthos
  kubectl --context cluster2 get pods -n bank-of-anthos
  # Inspect the SPIFFE identity in a sidecar's certificate:
  POD=$(kubectl --context cluster1 get pod -n bank-of-anthos -l app=frontend -o jsonpath='{.items[0].metadata.name}')
  kubectl --context cluster1 exec "$POD" -n bank-of-anthos -c istio-proxy -- \
    cat /var/run/secrets/workload-spiffe-credentials/certificates.pem \
    | openssl x509 -noout -text | grep -E "URI:"
  ```

### E. Multi-cluster gateway & global load balancing

A single global IP (`bank-of-anthos`) is reserved and a `MultiClusterIngress` (`bank-of-anthos-mci`) on the config cluster provisions a global external Application Load Balancer whose backends span every cluster. Google's network routes each user to the nearest healthy cluster. Note that the `MultiClusterIngress` manifest carries no `networking.gke.io/static-ip` or `networking.gke.io/pre-shared-certs` annotation, so the load balancer does **not** adopt the reserved global address, and the `ManagedCertificate` and `FrontendConfig` (HTTP→HTTPS 301) objects applied to the config cluster are not referenced by it — the single-cluster `Ingress` manifest that would bind them (`manifests/ingress.yaml`) is generated but never applied. Read the load balancer's actual address from the `MultiClusterIngress` status (`kubectl get mci -n bank-of-anthos -o jsonpath='{.items[0].status.VIP}'`).

- **Console:** Network Services → Load balancing shows the global load balancer, its frontends, the backend service, and the health of each per-cluster Network Endpoint Group.
- **CLI:**
  ```bash
  gcloud compute addresses list --global --project "$PROJECT" --filter="name~bank"
  kubectl --context cluster1 get multiclusteringress -n bank-of-anthos
  kubectl --context cluster1 get managedcertificate -n bank-of-anthos \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.certificateStatus}{"\n"}{end}'
  # Backend health per cluster NEG:
  BACKEND=$(gcloud compute backend-services list --global --project "$PROJECT" \
    --filter="name~bank-of-anthos" --format="value(name)" | head -1)
  gcloud compute backend-services get-health "$BACKEND" --global --project "$PROJECT"
  ```

### F. Networking (VPC, NAT, firewall)

All clusters share one global-routing VPC. Each cluster gets its own subnet with secondary ranges for pods and services, a Cloud Router + Cloud NAT for private egress, a reserved static external IP, and a set of firewall rules (internal traffic, the GKE control plane, load-balancer health checks, and the ASM webhook ports). Note that the module also creates an `allow-ssh-<deployment_id>` rule opening **TCP/22 to the whole VPC from `0.0.0.0/0`** — narrow or delete it if you keep the deployment beyond a demo.

- **Console:** VPC network → VPC networks → the deployment's network; VPC network → Firewall.
- **CLI:**
  ```bash
  gcloud compute networks subnets list --project "$PROJECT" \
    --format="table(name,region,ipCidrRange)"
  gcloud compute firewall-rules list --project "$PROJECT" \
    --format="table(name,direction,allowed[].map().firewall_rule().list())"
  ```

### G. Observability (Logging, Monitoring, Prometheus, Trace)

Pod logs flow to Cloud Logging; GKE and mesh metrics flow to Cloud Monitoring and Managed Prometheus; the mesh sends distributed traces to Cloud Trace. All of this aggregates across the fleet, so you can compare clusters side by side.

- **Console:** Logging → Logs Explorer; Monitoring → Dashboards (GKE group); Kubernetes Engine → Service Mesh for golden signals.
- **CLI:**
  ```bash
  gcloud logging read \
    'resource.type="k8s_container" AND resource.labels.namespace_name="bank-of-anthos"' \
    --project "$PROJECT" --limit 20 \
    --format="table(timestamp,resource.labels.cluster_name,resource.labels.location)"
  kubectl --context cluster1 top pods -n bank-of-anthos
  kubectl --context cluster2 top pods -n bank-of-anthos
  ```

### H. The Bank of Anthos application

Bank of Anthos is a retail-banking simulation: sign up, log in, view balances, and transfer funds. It comprises a `frontend`, `userservice`, `contacts`, `ledgerwriter`, `balancereader`, `transactionhistory`, a `loadgenerator` (continuous synthetic traffic), and the `accounts-db` / `ledger-db` PostgreSQL databases. The load generator keeps traffic flowing so the mesh dashboards and traces show live data immediately. Authentication uses a JWT key pair stored as the `jwt-key` Kubernetes Secret.

- **Console:** Kubernetes Engine → Workloads (filter by the `bank-of-anthos` namespace), per cluster.
- **CLI:**
  ```bash
  kubectl --context cluster1 get deploy,statefulset,svc -n bank-of-anthos
  kubectl --context cluster2 get deploy,statefulset,svc -n bank-of-anthos   # note: no DB StatefulSets here
  ```

---

## 3. Behaviour

**What gets deployed on apply.** The module enables the required project APIs, creates (or reuses) the shared VPC and per-cluster subnets/NAT/firewalls, then creates `cluster_size` GKE clusters across the chosen regions. Each cluster is registered into the fleet and the module waits for every membership to reach `READY` (polled up to ~10 minutes) before continuing. If the mesh is enabled, it is turned on at the fleet level and per membership in automatic-management mode, and the module waits for the mesh to configure on each cluster.

**Application rollout across clusters.** With `deploy_application = true`, the module downloads the pinned Bank of Anthos release (v0.6.10), creates the `bank-of-anthos` namespace (labelled for sidecar injection) on each cluster, applies the JWT secret, and applies the workload manifests:

- On the **primary cluster** (`cluster1`) the full manifest set is applied, **including** the `accounts-db` and `ledger-db` StatefulSets.
- On **every other cluster** the same manifests are applied but the database StatefulSets are stripped out — the stateless services and the database Services/ConfigMaps are still created so other pods can resolve them, and they are designed to use the databases on the primary cluster across the fleet. Any pre-existing DB StatefulSets on non-primary clusters are removed.

The module waits for deployments to become available on each cluster before reporting success.

**Global ingress.** After the app is running, the module enables the Multi-Cluster Ingress fleet feature (config cluster = `cluster1`) and applies, on the config cluster, the `MultiClusterService` (frontend backends across clusters), the `MultiClusterIngress` (the global load balancer), a NodePort service + BackendConfig (load-balancer health checks), the managed certificate for `boa.<GLOBAL_IP>.sslip.io`, the FrontendConfig (HTTPS redirect), and a mesh telemetry ConfigMap in `istio-system`. Traffic then flows: user → global anycast IP → nearest healthy cluster's NEG → frontend pod (Envoy sidecar) → downstream services over mesh mTLS.

**Manual follow-up.** The Google-managed certificate provisions asynchronously and can take **10–60 minutes** to become `Active`; until then HTTPS may warn or fail. Use the demo credentials shown on the Bank of Anthos sign-in page to log in. To enable CDN, custom domains, IAP, or cross-cluster traffic policies (VirtualService/DestinationRule), apply the relevant Kubernetes resources after deployment.

**Runtime notes.** Each app pod runs `2/2` (app + sidecar). The mesh shares one trust domain, so cross-cluster calls are mutually authenticated. Because the data tier lives only on the primary cluster, scaling the primary to zero or losing its region affects the databases — the stateless frontends on other clusters stay reachable through the global load balancer but depend on the primary for data.

**Destroy.** Tear-down runs ordered cleanup steps that remove the Multi-Cluster Ingress/Service resources, disable the mesh and Multi-Cluster Ingress fleet features, unregister fleet memberships, and delete leftover MCS firewall rules and NEGs before removing the clusters and VPC. APIs enabled by the module are left enabled to avoid disrupting other workloads.

---

## 4. Configuration Variables

Variables are grouped exactly as they appear on the deployment platform.

### Group 1 — Project & Regions

| Variable | Default | Description |
|---|---|---|
| `project_id` | _(required)_ | Target Google Cloud project. Must already exist. |
| `tenant_id` | `demo` | Tenant identifier. Must be 1–20 lowercase letters, numbers and hyphens — other values fail validation. Present on the form but not referenced by any resource in this module. |
| `available_regions` | `["us-west1", "us-east1"]` | Regions clusters are placed into, round-robin by cluster index. If fewer regions than clusters, regions are cycled. Must have at least one entry. |

### Group 2 — Network

| Variable | Default | Description |
|---|---|---|
| `create_network` | `true` | Create a new shared VPC for all clusters. Set `false` to use an existing network named by `network_name`. |
| `network_name` | `vpc-network` | Name of the shared VPC. When creating, a unique suffix is appended automatically. |
| `subnet_name` | `vpc-subnet` | Base name for per-cluster subnets (`<subnet_name>-cluster<N>`). Used only when `create_network = true`. |

### Group 3 — GKE Clusters

| Variable | Default | Description |
|---|---|---|
| `create_autopilot_cluster` | `true` | Create Autopilot clusters (fully managed nodes). Set `false` for Standard clusters with managed node pools. Applies to all clusters. |
| `release_channel` | `REGULAR` | GKE release channel for all clusters: `RAPID`, `REGULAR`, `STABLE`, or `NONE`. |
| `cluster_size` | `2` | Number of GKE clusters to create. Minimum 2 for a meaningful multi-cluster demo; upper bound limited by regional quota. |

### Group 4 — Service Mesh

| Variable | Default | Description |
|---|---|---|
| `enable_cloud_service_mesh` | `true` | Install and configure Cloud Service Mesh (managed Istio) fleet-wide for mTLS, cross-cluster traffic, and unified observability. Google selects the mesh version from the clusters' `release_channel`; there is no version input. |

### Group 5 — Application

| Variable | Default | Description |
|---|---|---|
| `deploy_application` | `true` | Deploy Bank of Anthos across all clusters after they are created. Set `false` to provision cluster infrastructure only. |

---

## 5. Outputs

| Output | Description |
|---|---|
| `deployment_id` | The deployment ID (provided or auto-generated) used to suffix resource names. |
| `project_id` | The target project ID. |

> The application's public address is not exposed as a Terraform output. Retrieve the global IP from the reserved global address (`gcloud compute addresses list --global --filter="name~bank"`) or the `MultiClusterIngress` status, then browse to `https://boa.<GLOBAL_IP>.sslip.io`.

---

## 6. Configuration Pitfalls & Sensible Defaults

> Risk: **Critical** (data loss / outage / security) — **High** (service degraded) —
> **Medium** (cost or partial degradation) — **Low** (minor).

| Setting | Sensible value | Risk | Consequence if wrong |
|---|---|---|---|
| `cluster_size` | `2` (or more) | High | Setting `1` defeats the purpose — no multi-cluster ingress, mesh span, or failover. Very large values can exhaust regional quota and fail mid-apply. |
| `available_regions` | ≥ 2 distinct regions | High | A single region removes geo-redundancy; all clusters share one region's failure domain. |
| Primary cluster (`cluster1`) | treat as the data tier | Critical | The `accounts-db` / `ledger-db` databases run only on the primary cluster. Losing its region, or scaling it to zero, takes the data tier offline for every cluster. |
| `deployment_id` | set once, then leave | Critical | Changing it after first deploy forces recreation of named resources (VPC, clusters), destroying running state. |
| `release_channel` | leave at `REGULAR` unless you have a reason | High | The managed CSM revision label (`asm-managed`/`-rapid`/`-stable`) and the `istio-<revision>` mesh-config ConfigMap are both derived from this. Changing the channel after first deploy does **not** move the mesh — CSM keeps the channel it was provisioned with. |
| `create_network` / `network_name` | `true` for a fresh project | Medium | Pointing at a non-existent or overlapping existing network (when `false`) breaks subnet and cluster creation. |
| Managed certificate wait | allow 10–60 min | Medium | Browsing `https://boa.<IP>.sslip.io` before the certificate is `Active` shows TLS warnings or failures — expected during provisioning, not a deployment error. |
| `create_autopilot_cluster` | `true` | Low | Standard clusters add node-pool management and per-node cost; Autopilot is simpler and cheaper for this demo. |
| `enable_cloud_service_mesh` | `true` | Medium | Disabling it removes mTLS, cross-cluster traffic management, and the Service Mesh observability the module is built to demonstrate. |
| First-deploy time | budget 40–60 min | Low | Multi-cluster + fleet + managed mesh + global LB provisioning is inherently slow; do not assume a stall. |

---

This is a standalone, educational module that builds its own VPC, clusters, fleet, mesh, and global load balancer — it does not depend on a separate foundation module. For the upstream application, see the [Bank of Anthos repository](https://github.com/GoogleCloudPlatform/bank-of-anthos).
