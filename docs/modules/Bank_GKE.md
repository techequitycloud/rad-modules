# Bank of Anthos on GKE

<img src="https://storage.googleapis.com/rad-public-2b65/modules/Bank_GKE.png" alt="Bank of Anthos on GKE" style={{maxWidth: "100%", borderRadius: "8px"}} />

Bank of Anthos is Google Cloud's open-source reference banking application — a polyglot microservices demo (Python and Java services, two PostgreSQL databases, and a synthetic load generator) that mimics a retail bank with accounts, a transaction ledger, and a web frontend. This module is a **standalone** deployment: it builds its own VPC, GKE cluster, fleet membership, Cloud Service Mesh, and monitoring, then deploys the upstream Bank of Anthos manifests onto the cluster. It does not depend on any shared foundation module.

The module is intended for **education and demonstration** — exploring GKE Autopilot, a managed service mesh with automatic mTLS, fleet management, and Cloud Monitoring. It is not a production banking system.

This guide focuses on the Google Cloud services the module provisions and how to explore and operate them from the Console and the command line.

---

## What Bank of Anthos costs on RAD, and how that compares

**Bank of Anthos on RAD's GKE Autopilot module costs about US$24 a month in a project you own, with no licence fee for the software itself.** There is no RAD module fee for Bank of Anthos at all — you pay only for the Google Cloud resources it uses. Figures are as at 8 October 2026; sources are listed at the end of this section.

If you only need it occasionally — studying for a certification, a demo, a seasonal need — a RAD-managed project can be deleted and restored within 30 days for a handful of credits, so that about US$24 a month becomes close to nothing instead. See **Pause it for free**, below.

### What you pay on RAD

You pay for three things:

| | In a Google Cloud project you own | In a project RAD manages for you |
|---|---|---|
| Module fee, once per deployment | 0 credits — free in both an owned and a RAD-managed project | 0 credits — free |
| Build time | A few credits, metered per minute of build time | The same |
| Google Cloud running cost | Billed by Google to your own billing account, about US$24 a month for the default configuration (table below) | Metered hourly in credits; RAD publishes **43 credits a day**, about 1,290 a month (about US$129 at the top-up price, US$103 at the Scale plan's rate) |
| Who owns what | You own the project and its billing; RAD deploys and updates it | RAD owns the project, with guardrails, quotas and budget alerts; you get console access, and a minimum purchased balance is held in reserve |

10 credits cost US$1 on a one-off top-up, and less on a monthly plan.

**Default running cost in your own project** (us-central1, Google list prices):

| Resource (module default) | Per month |
|---|---|
| GKE Autopilot pod, 0.5x vCPU / 0.5 GiB | US$18.04 |
| Cloud NAT and networking | US$5 |
| Cloud Storage (add-ons, backups) | US$1 |
| GKE cluster management fee | US$0 if this is your only Autopilot/zonal cluster on the billing account, otherwise about US$73 (shared across every GKE app in the project) |
| **Total** | **about US$24** |

### How it compares

- **Bank of Anthos is a free reference application, not a product with a commercial competitor — the honest comparison is against running the same sample yourself.** A local Kubernetes-in-Docker or Minikube cluster is free, but you then set up the service mesh, fleet registration and monitoring by hand, and you tear it down and rebuild it yourself every time.
- **RAD's small running cost here buys the managed wiring, not cheaper compute.** Cloud Service Mesh with automatic mTLS, fleet membership and Cloud Monitoring are already connected, on real Google Cloud infrastructure, for about US$24 a month with no module fee — useful for a certification lab or a demo you want to keep handy, rather than rebuilding the walkthrough from scratch each time.

### Pause it for free: delete a RAD-managed project, restore it when you need it

If Bank of Anthos runs in **a project RAD manages for you**, you have an option that goes well beyond
scaling to zero: **delete the whole project, and restore it within 30 days for close to
nothing.** This suits occasional use — studying for a certification, a demo, a seasonal
need — far better than running Bank of Anthos continuously.

- **How it works.** Deleting a RAD-managed project unlinks its billing first, then asks Google
  to delete the project outright. Google does not remove it immediately: it keeps the project,
  recoverable, for 30 days, and because billing is already unlinked nothing is charged while it
  waits. Unlike deleting one module, this does not tear down the database, any VM or the
  compute resource one by one — the whole project simply stops, and nothing is billed in the
  meantime.
- **Restoring costs a handful of credits, not a rebuild.** Within 30 days, only the project's
  owner can restore it. RAD asks Google to undelete the project and reattaches its billing
  account, then asks you to run **Update** on each deployment to confirm everything came back.
  Because nothing was individually destroyed, that Update finds the same resources already
  there — it is a check, not a rebuild, and an Update never charges the module fee again. This
  costs only a handful of credits in total (under US$1), against paying the module fee and a
  full build again.
- **What this needs.** You must own the project (not one RAD only manages billing for), you
  must restore it yourself within the 30 days — after that Google deletes it for good — and
  restoring is admitted like creating a new project, so your purchased credit balance must
  still clear the tier's floor (100 credits for the sandbox tier most study and demo use
  fits). Google says most services are fully working again within 36 hours of a restore.
- **One real gap: backups do not survive.** Anything Bank of Anthos writes to a backup bucket inside the
  project is very likely gone as soon as you delete the project, even though the project itself
  is recoverable for 30 days — that bucket has Cloud Storage's soft-delete explicitly turned
  off. Anyone who has customised the deployment and wants to keep that work should copy a
  backup out (to Google Drive, or a bucket outside the project) before deleting. For a default
  install with nothing irreplaceable in it, this does not matter.

### Pay only while you use it, the other way: delete and redeploy

This is the fallback for a project you own, or once the 30-day restore window above has
passed: **delete the deployment, and deploy it again when you next need it.**

- **What a redeploy costs.** The module fee again, plus the builds: roughly
  5 credits (about US$0.50) in your own project, or
  5 credits in a RAD-managed one, because RAD rebuilds the resources
  from scratch. There is no module fee here, so a redeploy costs only a few credits of build time — about 5 credits (under US$1). Deleting between uses almost always pays for itself; there is very little fee to recoup.
- **The GKE cluster itself is shared infrastructure.** If another application uses the same Autopilot cluster, deleting Bank of Anthos alone saves only its own pod; the cluster management fee only drops once nothing else in the project needs it.
- **Keep your data first.** Anything Bank of Anthos writes to a backup bucket inside the deployment is
  deleted with it — copy the latest backup out (to Google Drive, or a bucket you keep) before
  deleting if you want to keep it.
- **RAD does not recreate a deleted deployment for you.** You enter the settings again when
  you redeploy.

### Lab sessions and Managed Environments

- **Lab sessions, for training.** A trainer runs a session for a class. Each participant gets
  Bank of Anthos in their own Google Cloud project for 15 minutes to 24 hours, within an allowance the
  trainer sets. Either the trainer funds every place, or each participant pays for their own.
  Everything is deleted when the session ends and unused credits go back to the trainer.
- **Managed Environments, for consultancies.** A partner runs Bank of Anthos for a client from a
  ring-fenced wallet it funds, and settles with the client directly. If the wallet runs low,
  billing pauses and the data is kept, so nobody receives an unexpected charge. At the end the
  partner hands the project over and the deployments become the client's own.

Credits can be bought in more than 20 currencies, including XAF, XOF, NGN, GHS, KES and ZAR,
by card, bank transfer or mobile money.

**Sources (8 October 2026):** Google Cloud list prices from the Cloud Billing Catalog API; RAD's fees and daily-credit estimate from [radmodules.dev/pricing](https://radmodules.dev/pricing); [Delete and restore projects](https://cloud.google.com/resource-manager/docs/delete-restore-projects) for the pause/restore mechanics. Prices change; check each source before relying on a figure.

## 1. Overview

The module wires together a focused set of Google Cloud services around the Bank of Anthos workload:

| Capability | Google Cloud service | Notes |
|---|---|---|
| Compute | GKE Autopilot (or Standard) | Single regional cluster; Autopilot is the default and provisions/scales nodes automatically |
| Network | VPC, subnet, Cloud Router + Cloud NAT, firewall rules | A dedicated VPC with VPC-native secondary ranges for pods and services; NAT for egress |
| Service mesh | Cloud Service Mesh (Google-managed Istio) | Enabled via the fleet with `MANAGEMENT_AUTOMATIC`; injects Envoy sidecars and enforces mTLS |
| Fleet | GKE Hub / Fleet membership | The cluster is registered in the fleet, which is required to enable the mesh feature |
| Ingress | Cloud Load Balancing (external L4) | The frontend is exposed via the upstream `frontend` Service of type LoadBalancer; a global static IP is also reserved |
| Observability | Cloud Monitoring, Managed Service for Prometheus, Cloud Logging, Cloud Trace | Managed Prometheus on the cluster; one monitored service + CPU-utilisation SLO per workload |
| Application | Bank of Anthos `v0.6.10` workloads | Nine workloads — seven microservice Deployments plus two PostgreSQL StatefulSets — in the `bank-of-anthos` namespace |

**Things to know up front:**

- **This is a standalone module.** It creates its own VPC, GKE cluster, and supporting infrastructure. There is no separate platform/foundation module to deploy first — only a GCP project with billing enabled.
- **Autopilot is the default.** `create_autopilot_cluster = true` gives a fully Google-managed cluster. Set it to `false` for a Standard cluster, in which case the module provisions a Spot node pool (`e2-standard-2`) with 2 nodes per zone in every available zone of the region, and a dedicated node service account with Workload Identity.
- **The application is exposed over plain HTTP (L4).** The Bank of Anthos `frontend` Service is type `LoadBalancer`, so it receives a regular external IP serving HTTP. The module also reserves a global static IP named `bank-of-anthos`, but the demo does not provision an HTTPS load balancer, managed TLS certificate, or custom domain.
- **The mesh control plane is fully managed.** With `enable_cloud_service_mesh = true`, Google runs the Istio control plane — no `istiod` pods run in your cluster. The `bank-of-anthos` namespace is labelled `istio.io/rev=asm-managed`, which triggers automatic Envoy sidecar injection so every pod runs `2/2`.
- **Apply waits for the mesh to be ready.** Provisioning verifies the fleet membership and mesh control plane reach `ACTIVE` before deploying the application, so first deploys take a while (roughly 30–45 minutes).
- **Config Management inputs are present but not active.** `enable_config_management` and its related inputs exist for forward compatibility, but this module does **not** currently provision Anthos Config Management / Config Sync resources. Leave it at the default.
- **The application manifests are fetched from GitHub at apply time.** The module downloads the Bank of Anthos `v0.6.10` release archive and applies its Kubernetes manifests with `kubectl`. Outbound internet access from the deployment runner is required.

---

## 2. Google Cloud Services & How to Explore Them

All commands assume you have run
`gcloud container clusters get-credentials <cluster> --region <region> --project <project>`
and that `PROJECT` and `REGION` are set. The cluster name defaults to `gke-cluster`; the application namespace is `bank-of-anthos`.

### A. GKE — the cluster and the banking workload

The cluster runs all nine Bank of Anthos workloads — seven microservice Deployments plus the `accounts-db` and `ledger-db` PostgreSQL StatefulSets — in the `bank-of-anthos` namespace. On Autopilot, nodes are provisioned and scaled automatically; on Standard, a 2-node Spot node pool is created. Managed Prometheus, the GCS FUSE CSI driver, the Gateway API, GKE cost management, and BASIC security posture (with workload vulnerability scanning) are all enabled on the cluster.

- **Console:** Kubernetes Engine → Clusters (mode, version, add-ons); Workloads (the nine services); Security Posture (vulnerability and misconfiguration findings).
- **CLI:**
  ```bash
  gcloud container clusters describe gke-cluster --region "$REGION" --project "$PROJECT" \
    --format="table(name,autopilot.enabled,currentMasterVersion,status)"
  kubectl get pods -n bank-of-anthos          # expect every pod 2/2 (app + Envoy sidecar)
  kubectl get statefulset,pvc -n bank-of-anthos
  kubectl get nodes -o wide
  ```

### B. Cloud Service Mesh

Cloud Service Mesh is enabled as a fleet feature with `MANAGEMENT_AUTOMATIC`. Google manages the Istio control plane; Envoy sidecars are injected into every pod in the `bank-of-anthos` namespace, encrypting all pod-to-pod traffic with mTLS and emitting golden-signal telemetry without any application instrumentation.

- **Console:** Kubernetes Engine → Service Mesh — live topology graph, per-service latency/traffic/errors, control-plane health.
- **CLI:**
  ```bash
  gcloud container fleet mesh describe --project "$PROJECT"
  kubectl get namespace bank-of-anthos --show-labels        # istio.io/rev=asm-managed
  # Confirm each pod has an istio-proxy sidecar:
  kubectl get pods -n bank-of-anthos \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.containers[*]}{.name}{" "}{end}{"\n"}{end}'
  ```

### C. GKE Fleet

The cluster is registered as a fleet membership immediately after creation. Fleet membership is the prerequisite for enabling the mesh feature, and it provides a single place to view feature state across clusters.

- **Console:** Kubernetes Engine → Fleets — membership state and enabled features.
- **CLI:**
  ```bash
  gcloud container fleet memberships list --project "$PROJECT"
  gcloud container fleet memberships describe gke-cluster --location global --project "$PROJECT"
  gcloud container fleet features list --project "$PROJECT"
  ```

### D. Networking & load balancing

The module creates a dedicated VPC (GLOBAL routing) with a subnet that carries VPC-native secondary ranges for pods and services, a Cloud Router + Cloud NAT gateway for egress, and a set of firewall rules (load-balancer and NFS health-check ranges, IAP-tunnelled SSH, intra-VPC pod traffic, HTTP/HTTPS). A global static external IP named `bank-of-anthos` is reserved. The application frontend is reached through the upstream `frontend` Service of type LoadBalancer.

- **Console:** VPC network → VPC networks / Firewall; Network services → Cloud NAT and Load balancing; VPC network → IP addresses.
- **CLI:**
  ```bash
  gcloud compute networks subnets list --project "$PROJECT" \
    --format="table(name,region,ipCidrRange,secondaryIpRanges[].rangeName)"
  gcloud compute addresses list --global --project "$PROJECT"
  # External IP the application is actually served on:
  kubectl get svc frontend -n bank-of-anthos \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
  ```

### E. Cloud Monitoring, Prometheus, Logging & Trace

Managed Service for Prometheus runs on the cluster. When monitoring is enabled, the module registers each of the nine workloads as a Cloud Monitoring service and attaches a CPU-limit-utilisation SLO to each. Pod stdout/stderr flows to Cloud Logging, and mesh sidecars export distributed traces to Cloud Trace.

- **Console:** Monitoring → Dashboards (GKE) and Services → SLOs; Logging → Logs Explorer; Trace → Trace list.
- **CLI:**
  ```bash
  gcloud monitoring services list --project "$PROJECT"
  gcloud logging read 'resource.type="k8s_container" AND resource.labels.namespace_name="bank-of-anthos"' \
    --project "$PROJECT" --limit 50
  ```

### F. The Bank of Anthos workloads

Nine services in three tiers: `frontend` (Python web UI); `userservice`, `contacts`, and `accounts-db` (account management plus PostgreSQL); `ledgerwriter`, `balancereader`, `transactionhistory`, and `ledger-db` (transactions plus PostgreSQL); and `loadgenerator`, which drives synthetic traffic so telemetry and SLOs have data. Services communicate over HTTP by Kubernetes DNS name; an RSA-signed JWT (stored as a Kubernetes Secret) authenticates users across services.

- **CLI:**
  ```bash
  kubectl get all -n bank-of-anthos
  kubectl logs -n bank-of-anthos deploy/frontend --tail=50
  kubectl logs -n bank-of-anthos deploy/loadgenerator --tail=20
  ```

---

## 3. Behaviour

- **Standalone provisioning.** A successful apply creates the VPC and subnet (with pod/service secondary ranges), Cloud Router + NAT, firewall rules, the GKE cluster, the fleet membership, the Cloud Service Mesh feature, the monitored services and SLOs, a reserved global static IP, and the Bank of Anthos workloads.
- **The Bank of Anthos components.** With `deploy_application = true` the module deploys nine microservices — `frontend`, `userservice`, `contacts`, `ledgerwriter`, `balancereader`, `transactionhistory`, `loadgenerator`, and the `accounts-db` and `ledger-db` PostgreSQL databases — into the `bank-of-anthos` namespace, along with the JWT signing/verification secret.
- **Mesh-first ordering.** The apply enables the GKE Hub and mesh APIs, grants the GKE Hub service agent the roles it needs, registers the fleet membership, enables the mesh feature, and then **waits** (via polling) for the membership and mesh control plane to report `ACTIVE` before deploying the application. This is why first deploys take roughly 30–45 minutes.
- **Application deployment.** The module downloads the Bank of Anthos `v0.6.10` release archive from GitHub, creates the `bank-of-anthos` namespace labelled with the channel-matching CSM revision (`istio.io/rev=asm-managed` for `REGULAR`, `-rapid`/`-stable` for the other channels), applies the JWT secret and the Kubernetes manifests with `kubectl`, and waits for all deployments to become available. It also creates a project-local Workload Identity service account (`bank-of-anthos@<project>.iam.gserviceaccount.com`), grants it `roles/cloudtrace.agent` and `roles/monitoring.metricWriter`, binds it to the `bank-of-anthos` Kubernetes service account, and re-annotates that KSA — the upstream v0.6.10 manifests hardcode a service account in Google's own CI project, which otherwise crashes the Java services at startup.
- **Mesh injection.** Because the namespace carries the `asm-managed` revision label, every pod is injected with an Envoy sidecar at admission and runs `2/2`. All in-namespace traffic is mTLS-encrypted by default.
- **How the app is exposed.** The upstream `frontend` Service is type `LoadBalancer`, so Google Cloud assigns it an external IP serving plain HTTP on port 80. The reserved global static IP and the Gateway API add-on are available for advanced exposure patterns but are not wired into an HTTPS load balancer by this module.
- **Monitoring & SLOs.** When `enable_monitoring = true`, one Cloud Monitoring service and one CPU-limit-utilisation SLO (95% goal, daily calendar period, 5-minute windows) are created per workload, giving a ready-made SLO framework to explore.
- **Manual follow-up.** TLS/HTTPS, a custom domain, IAP in front of the frontend, traffic-management policies (VirtualService/DestinationRule), and any GitOps/Config Sync setup are not provisioned by the module and must be configured manually after deploy if desired.
- **Standard-mode extras.** With `create_autopilot_cluster = false`, the module additionally creates a node service account, a Spot node pool (`e2-standard-2`, 50 GB pd-ssd) sized at **2 nodes per zone across every available zone in the region** (8 nodes in a four-zone region such as `us-central1`), and the IAM bindings and Workload Identity pool that Autopilot would otherwise provide automatically.
- **Runtime notes.** The release archive is re-downloaded on every apply, so updates re-fetch the manifests; the demo databases (`accounts-db`, `ledger-db`) hold all account and transaction data and are deleted with the cluster on teardown.

---

## 4. Configuration Variables

Variables are grouped exactly as they appear on the deployment platform.

### Group 1 — Project & Region

| Variable | Default | Description |
|---|---|---|
| `project_id` | _(uses default project)_ | Destination GCP project where the cluster and application are deployed. The provisioning service account must hold `roles/owner` in it. |
| `region` | `us-central1` | Region for the cluster, VPC, and all regional resources. Ensure quota is available. |
| `tenant_id` | `demo` | Tenant identifier used in resource naming. Must be 1–20 characters, lowercase letters, digits and hyphens only — anything else fails validation at plan time. |

### Group 2 — Network

| Variable | Default | Description |
|---|---|---|
| `create_network` | `true` | Create a new VPC and subnet. Set `false` to use an existing network identified by `network_name`/`subnet_name`. |
| `network_name` | `vpc-network` | Name of the VPC (created or referenced). |
| `subnet_name` | `vpc-subnet` | Name of the subnet (created or referenced). |
| `ip_cidr_ranges` | `["10.132.0.0/16", "192.168.1.0/24"]` | CIDR blocks for the subnet. Only used when `create_network = true`; the first is the primary node range. |

### Group 5 — Cluster

| Variable | Default | Description |
|---|---|---|
| `create_cluster` | `true` | Create a new GKE cluster. Set `false` to deploy onto an existing cluster named by `gke_cluster`. |
| `create_autopilot_cluster` | `true` | `true` for Autopilot (fully managed nodes); `false` for Standard (a 2-node Spot node pool is created). |
| `gke_cluster` | `gke-cluster` | Name of the cluster (created or referenced). Also used as the fleet membership ID. |
| `release_channel` | `REGULAR` | Upgrade cadence: `RAPID`, `REGULAR`, `STABLE`, or `NONE`. |
| `pod_cidr_block` | `10.62.128.0/17` | Secondary range for pod IPs (VPC-native). Must not overlap node/service ranges. |
| `service_cidr_block` | `10.64.128.0/20` | Secondary range for Kubernetes Service ClusterIPs. Must not overlap node/pod ranges. |

> The platform also exposes `pod_ip_range` (default `pod-ip-range`) and `service_ip_range` (default `service-ip-range`) — the alias names for the two secondary ranges above. Leave them at their defaults unless you are attaching to existing named ranges on an existing subnet.

### Group 6 — Features

| Variable | Default | Description |
|---|---|---|
| `enable_monitoring` | `true` | Enable Managed Prometheus and create the per-workload Cloud Monitoring services and SLOs. |
| `enable_cloud_service_mesh` | `true` | Install and configure Cloud Service Mesh (managed Istio) with `MANAGEMENT_AUTOMATIC` — provides mTLS and mesh telemetry. Google selects the mesh version from the cluster's `release_channel`; there is no version input. |
| `enable_config_management` | `false` | Reserved for Anthos Config Management. Not currently wired to any resource in this module — leave at default. |
| `config_sync_repo` | _(GCP ACM samples repo)_ | Reserved Config Sync Git repository URL (inactive — see above). |
| `config_sync_policy_dir` | _(quickstart multi-repo root)_ | Reserved Config Sync policy directory within the repo (inactive — see above). |

### Group 7 — Application

| Variable | Default | Description |
|---|---|---|
| `deploy_application` | `true` | Deploy the Bank of Anthos `v0.6.10` microservices onto the cluster. Set `false` to provision the cluster and infrastructure only. |

---

## 5. Outputs

| Output | Description |
|---|---|
| `deployment_id` | The deployment ID used to make resource names unique (the value you supplied, or `null` when auto-generated by the platform). |
| `project_id` | The destination project ID the module deployed into. |

> The application's external address is not surfaced as a Terraform output; retrieve it from the `frontend` LoadBalancer Service: `kubectl get svc frontend -n bank-of-anthos`.

---

## 6. Configuration Pitfalls & Sensible Defaults

> Risk: **Critical** (data loss / outage / security) — **High** (service degraded) —
> **Medium** (cost or partial degradation) — **Low** (minor).

| Setting | Sensible value | Risk | Consequence if wrong |
|---|---|---|---|
| `enable_cloud_service_mesh` | `true` | High | With the mesh off, no sidecars are injected — pods run `1/1`, there is no mTLS or mesh telemetry, and the mesh-readiness wait that gates the app deploy is skipped. |
| `deployment_id` | set once (or leave auto) | High | Changing it after first deploy renames resources and forces recreation of the VPC/cluster — effectively a fresh deployment. |
| `pod_cidr_block` / `service_cidr_block` / `ip_cidr_ranges` | non-overlapping CIDRs | High | Overlapping or too-small secondary ranges cause cluster creation to fail or exhaust pod/service IPs as the app scales. |
| `region` | a region with quota | High | Insufficient CPU/IP/SSD quota in the chosen region fails cluster or node-pool creation midway through a long apply. |
| `enable_config_management` | `false` | Medium | The inputs are not wired to any resource; enabling it sets expectations of GitOps/Config Sync that the module does not deliver. |
| `create_autopilot_cluster` | `true` | Medium | Standard mode uses a 2-node Spot pool — cheaper but preemptible; nodes can be reclaimed, briefly disrupting workloads. Use Autopilot for steadier behaviour. |
| Application exposure (HTTP only) | add TLS/IAP manually | Medium | The frontend is served over plain HTTP on a public IP. For anything beyond a demo, front it with HTTPS and/or IAP after deploy. |
| `create_network = false` | matching existing subnet | Medium | The existing subnet must already carry secondary ranges whose names match `pod_ip_range`/`service_ip_range`, or cluster creation fails. |
| `release_channel` | `REGULAR` | Low | `RAPID` upgrades frequently (more churn); `NONE` leaves the cluster on manual upgrades and can drift behind supported versions. |
| `enable_monitoring` | `true` | Low | Disabling it removes the per-workload monitored services and SLOs, so the SLO/observability walkthrough has nothing to show. |

---

For the end-to-end operational walkthrough — deploy, access, day-2 operations, observability, troubleshooting, and teardown — see the **[Bank of Anthos on GKE lab guide](../labs/Bank_GKE.md)**.
