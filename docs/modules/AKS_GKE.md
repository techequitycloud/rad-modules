# Azure AKS attached to a Google Cloud Fleet

<img src="https://storage.googleapis.com/rad-public-2b65/modules/AKS_GKE.png" alt="Azure AKS attached to a Google Cloud Fleet" style={{maxWidth: "100%", borderRadius: "8px"}} />

This module creates a Microsoft Azure Kubernetes Service (AKS) cluster and registers it with Google Cloud as a **GKE Attached Cluster** — a full member of a **GKE Fleet**. Once attached, the AKS cluster appears in the Google Cloud Console alongside any native GKE clusters in the project, and can be accessed, observed, and governed through the same Google Cloud tooling, IAM model, and observability stack used for GKE — without migrating or refactoring the workloads that run on it.

Unlike the application modules in this catalogue, this is a **standalone module** with no shared foundation. It owns its own Azure provider and creates resources in **two clouds**: an Azure Resource Group and AKS cluster on the Azure side, and a fleet membership plus managed logging and monitoring configuration on the Google Cloud side. The AKS cluster continues to run entirely in Azure; Google Cloud only gains a management plane over it. Trust between the two clouds is established with OIDC federation, so no service-account keys or shared secrets are exchanged.

---

## What AKS costs on RAD, and how that compares

**AKS on RAD's GKE Autopilot module costs about US$24 a month in a project you own, with no licence fee for the software itself.** There is no RAD module fee for AKS at all — you pay only for the Google Cloud resources it uses. Figures are as at 8 October 2026; sources are listed at the end of this section.

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

- **There is no SaaS alternative to name here — this module is a thin control-plane layer, not a hosted app.** The real alternative is doing the same work by hand: creating the Azure AKS cluster yourself and registering it with `gcloud container fleet memberships register`, from two separate consoles, with no incremental Google Cloud cost beyond the small Autopilot pod this module already runs (shown above).
- **What you are paying for is the automation and the cross-cloud trust setup, not a cheaper way to run AKS.** OIDC federation between the two clouds, fleet registration and the managed logging/monitoring wiring are what the module fee (zero, here) and build time actually buy — the ongoing Google-side running cost is the same either way.
- **The AKS cluster itself is billed by Microsoft Azure, not Google Cloud, and this module's figures do not include it.** Azure's own AKS pricing (compute nodes, and its per-cluster management fee outside the Free tier) is a separate bill on your Azure account — check the Azure AKS pricing page for that side.

### Pause it for free: delete a RAD-managed project, restore it when you need it

If AKS runs in **a project RAD manages for you**, you have an option that goes well beyond
scaling to zero: **delete the whole project, and restore it within 30 days for close to
nothing.** This suits occasional use — studying for a certification, a demo, a seasonal
need — far better than running AKS continuously.

- **This pauses the Google Cloud side only — the fleet membership, monitoring and the small Autopilot pod shown above. The AKS cluster itself runs in, and is billed by, Microsoft Azure, and keeps running (and costing money on Azure) until you pause or delete it there separately.**

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
- **One real gap: backups do not survive.** Anything AKS writes to a backup bucket inside the
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
- **The GKE cluster itself is shared infrastructure.** If another application uses the same Autopilot cluster, deleting AKS alone saves only its own pod; the cluster management fee only drops once nothing else in the project needs it.
- **Keep your data first.** Anything AKS writes to a backup bucket inside the deployment is
  deleted with it — copy the latest backup out (to Google Drive, or a bucket you keep) before
  deleting if you want to keep it.
- **RAD does not recreate a deleted deployment for you.** You enter the settings again when
  you redeploy.

### Lab sessions and Managed Environments

- **Lab sessions, for training.** A trainer runs a session for a class. Each participant gets
  AKS in their own Google Cloud project for 15 minutes to 24 hours, within an allowance the
  trainer sets. Either the trainer funds every place, or each participant pays for their own.
  Everything is deleted when the session ends and unused credits go back to the trainer.
- **Managed Environments, for consultancies.** A partner runs AKS for a client from a
  ring-fenced wallet it funds, and settles with the client directly. If the wallet runs low,
  billing pauses and the data is kept, so nobody receives an unexpected charge. At the end the
  partner hands the project over and the deployments become the client's own.

Credits can be bought in more than 20 currencies, including XAF, XOF, NGN, GHS, KES and ZAR,
by card, bank transfer or mobile money.

**Sources (8 October 2026):** Google Cloud list prices from the Cloud Billing Catalog API; RAD's fees and daily-credit estimate from [radmodules.dev/pricing](https://radmodules.dev/pricing); [Delete and restore projects](https://cloud.google.com/resource-manager/docs/delete-restore-projects) for the pause/restore mechanics. Prices change; check each source before relying on a figure.

## 1. Overview

The module provisions infrastructure across both clouds. On apply it (1) creates the Azure Resource Group and AKS cluster, (2) installs the GKE Connect agent onto the cluster via Helm, and (3) registers the cluster as a GKE Attached Cluster and enrols it in the project's fleet with managed logging, Managed Prometheus, and an admin-user list.

| Capability | Cloud service | Notes |
|---|---|---|
| Kubernetes cluster | Azure AKS | Created in Azure with a system-assigned managed identity, OIDC issuer enabled, and a default node pool (3 nodes, `Standard_D2s_v3` by default). |
| Cluster networking | Azure Resource Group + role assignment | A Resource Group holds the cluster; the cluster's managed identity is granted Network Contributor so AKS can manage Azure load balancers for `LoadBalancer` Services. |
| Fleet membership | Google Cloud Fleet (GKE Hub) | The AKS cluster is registered as an attached cluster and becomes a fleet member, visible in the Console with distribution type `aks`. |
| Remote `kubectl` access | Connect gateway | Engineers run `kubectl` against the AKS cluster using their Google Cloud identity — no Azure credentials, kubeconfig distribution, or VPN required. |
| Cross-cloud trust | OIDC federation | Google Cloud validates Kubernetes tokens against the AKS OIDC issuer's public keys; no shared secrets between clouds. |
| Centralised logging | Cloud Logging | System-component and workload logs from AKS flow into the same project's Log Explorer. |
| Centralised metrics | Cloud Monitoring (Managed Prometheus) | A collector on AKS forwards Kubernetes metrics to Cloud Monitoring; built-in GKE dashboards populate automatically. |
| Access control | Google Cloud IAM + Kubernetes RBAC | Users listed in `trusted_users` (plus the deploying identity) are granted cluster-admin on the attached cluster. |

**Things to know up front:**

- **Azure credentials are required.** Four sensitive inputs — `client_id`, `client_secret`, `azure_tenant_id`, and `subscription_id` — identify an Azure AD service principal with at least Contributor rights on the target subscription. Without them the module cannot create the AKS cluster. They are marked sensitive and never appear in logs or plan output.
- **This is a two-cloud module.** You need both a Google Cloud project (billing enabled) and an Azure subscription. Costs accrue on both sides — Azure for the AKS nodes, Google Cloud for fleet management and observability ingestion.
- **The AKS cluster runs in Azure.** The control plane, nodes, and networking all live in Azure (`westus2` by default). Google Cloud only stores the attached-cluster record and fleet membership (in `us-central1` by default).
- **Platform version must be compatible with the Kubernetes version.** `platform_version` (the attached-component version, e.g. `1.35.0-gke.1`) must have a minor version equal to `k8s_version` (the AKS Kubernetes minor, e.g. `1.35`) or exactly one below it.
- **The deploying user is always an admin.** The identity running the deployment is automatically added to the cluster admin list, in addition to any `trusted_users`.
- **APIs are enabled non-destructively.** The module enables several Google Cloud APIs (GKE Multi-Cloud, GKE Connect, Connect Gateway, GKE Hub, Anthos, Logging, Monitoring, and related metadata APIs). These are left enabled on teardown so other workloads in the project are not disrupted.

---

## 2. Cloud Services & How to Explore Them

The Google Cloud side is explored with `gcloud` and `kubectl`; the Azure side with the `az` CLI. Set `PROJECT` to your Google Cloud project, `GCP_LOCATION` to the fleet region, and `CLUSTER` to the attached-cluster name (the value of `cluster_name_prefix`). Confirm the exact membership name with `gcloud container fleet memberships list`.

### A. GKE Attached Cluster & Fleet membership (Google Cloud)

The AKS cluster is registered as an attached cluster and enrolled in the fleet of the destination project. It appears in the Console with type `Attached` / distribution `aks`, alongside any native GKE clusters.

- **Console:** Kubernetes Engine → Clusters (the Azure cluster shows an Azure icon and type `Attached`); Kubernetes Engine → Fleet shows membership and feature health.
- **CLI:**
  ```bash
  # Fleet membership
  gcloud container fleet memberships list --project "$PROJECT"
  gcloud container fleet memberships describe "$CLUSTER" --project "$PROJECT"

  # Attached-cluster registration record (OIDC issuer, platform version, admin users)
  gcloud container attached clusters list --location "$GCP_LOCATION" --project "$PROJECT"
  gcloud container attached clusters describe "$CLUSTER" \
    --location "$GCP_LOCATION" --project "$PROJECT"
  ```

### B. Connect gateway — `kubectl` access (Google Cloud)

Fleet enrolment activates the Connect gateway, which proxies `kubectl` to the AKS cluster using Google Cloud IAM. The kubeconfig entry points at Google's gateway endpoint, not the AKS API server, so no inbound access to Azure is needed.

- **Console:** Kubernetes Engine → Clusters → select the cluster → Connect.
- **CLI:**
  ```bash
  # Configure kubectl to reach the cluster through the Connect gateway
  gcloud container fleet memberships get-credentials "$CLUSTER" --project "$PROJECT"

  kubectl config current-context        # connectgateway_<project>_global_<cluster>
  kubectl get nodes -o wide
  kubectl get namespaces
  kubectl get pods --all-namespaces
  ```

### C. Cloud Logging (Google Cloud)

System-component and workload logs are collected from AKS into the project's Log Explorer using the same schema as GKE, so existing GKE log queries work unchanged.

- **Console:** Logging → Logs Explorer.
- **CLI:**
  ```bash
  # All recent logs from the attached cluster
  gcloud logging read 'resource.labels.cluster_name="'"$CLUSTER"'"' \
    --project "$PROJECT" --limit 20

  # Workload (container) logs in a namespace
  gcloud logging read \
    'resource.type="k8s_container" AND resource.labels.cluster_name="'"$CLUSTER"'" AND resource.labels.namespace_name="default"' \
    --project "$PROJECT" --limit 20
  ```

### D. Cloud Monitoring & Managed Prometheus (Google Cloud)

Managed Service for Prometheus is enabled on the cluster. A collector on the AKS nodes forwards Kubernetes metrics to Cloud Monitoring; the built-in GKE dashboards populate automatically.

- **Console:** Monitoring → Metrics Explorer (filter a `kubernetes.io/...` metric by `cluster_name`); Monitoring → Dashboards → the GKE dashboards.
- **CLI:**
  ```bash
  gcloud monitoring metrics list \
    --filter='metric.type=starts_with("kubernetes.io/node")' --project "$PROJECT"
  # Through the Connect gateway:
  kubectl top nodes
  kubectl top pods --all-namespaces
  ```

### E. Azure AKS (Azure)

The cluster, its Resource Group, and node pool are managed in Azure. Authenticate the `az` CLI with the same service principal supplied to the module.

- **Console:** Azure Portal → Kubernetes services → the AKS cluster; Resource groups → `<cluster_name_prefix>-rg`.
- **CLI:**
  ```bash
  az login --service-principal \
    --username "$ARM_CLIENT_ID" --password "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID"

  az aks list --subscription "$ARM_SUBSCRIPTION_ID" --output table
  az aks show --resource-group "<cluster_name_prefix>-rg" \
    --name "<cluster_name_prefix>" --subscription "$ARM_SUBSCRIPTION_ID"
  ```

---

## 3. Behaviour

- **What apply does.** The module creates the Azure Resource Group and AKS cluster, grants the cluster's managed identity Network Contributor on the Resource Group, installs the GKE Connect agent onto the cluster via Helm, then registers the cluster as a GKE Attached Cluster and enrols it in the project's fleet. A first apply takes roughly **12–20 minutes**; AKS provisioning in Azure is the longest phase.
- **Outbound-only connectivity.** The Connect agent maintains a persistent, encrypted, outbound connection from AKS to Google Cloud. The AKS API server does not need a public endpoint, and no inbound firewall rules or VPN are required in Azure.
- **Connect-gateway access model.** Access is two-layered: a Google Cloud IAM role on the project (e.g. `roles/gkehub.gatewayReader`, `gatewayEditor`, or `gatewayAdmin`) authorises traversal of the gateway, and Kubernetes RBAC on the cluster authorises the specific API actions. Users in `trusted_users` (and the deploying identity) receive cluster-admin automatically.
- **Centralised observability is on by default.** Logging is configured for both system components and workloads, and Managed Prometheus is enabled, with no further configuration after attachment.
- **OIDC federation.** Google Cloud trusts tokens issued by the AKS OIDC issuer by validating their signatures against the cluster's published public keys — there are no shared credentials between Azure and Google Cloud.
- **Manual follow-up (optional).** A service-mesh sub-module (Google Cloud Service Mesh / Istio) ships with the module but is **not installed automatically**. Installing it is a separate, manual step and is outside the scope of a standard deployment.
- **Updates.** Changing `platform_version` updates only the attached-cluster registration / Connect agent — the AKS cluster itself is untouched. Changing `node_count` or `vm_size` reshapes the Azure node pool. Changing `cluster_name_prefix` forces resource recreation across both clouds (the cluster name does not incorporate the deployment ID, so two deployments with the same prefix in the same subscription and project will conflict).
- **Teardown.** Destroy deregisters the cluster from the fleet, removes the Connect agent, and deletes the Azure Resource Group and AKS cluster. The Google Cloud APIs enabled during deployment are intentionally left enabled.

---

## 4. Configuration Variables

Variables are grouped exactly as they appear on the deployment platform.

### Group 1 — Project & Identity

| Variable | Default | Description |
|---|---|---|
| `project_id` | _(required)_ | Destination Google Cloud project where the cluster is registered and the fleet membership is created. Must already exist. |
| `gcp_location` | `us-central1` | Google Cloud region where the attached-cluster record and fleet membership are stored and shown in the Console. Must support attached clusters. |
| `azure_region` | `westus2` | Azure region where the AKS cluster and its Resource Group are created. Feature and VM SKU availability varies by region. |
| `trusted_users` | _(required)_ | Google account emails granted cluster-admin on the AKS cluster via the Connect gateway. Has no default — supply an empty list `[]` if no additional admins are needed. The deploying identity is always included automatically. Entries must be non-blank and unique. |
| `client_id` | _(required, sensitive)_ | Azure AD application (client) ID of the service principal used to create and manage the AKS resources. |
| `client_secret` | _(required, sensitive)_ | Client secret for the Azure AD service principal. |
| `azure_tenant_id` | _(required, sensitive)_ | Azure AD tenant (directory) ID for the Azure account. |
| `subscription_id` | _(required, sensitive)_ | Azure subscription ID where the AKS resources are provisioned. |

### Group 4 — Cluster

| Variable | Default | Description |
|---|---|---|
| `cluster_name_prefix` | `azure-aks-cluster` | Prefix for the cluster and associated resource names (lowercase letters, digits, hyphens). Used verbatim as the cluster name in both Azure and Google Cloud, and to derive the Resource Group (`<prefix>-rg`) and DNS prefix (`<prefix>-dns`). |
| `node_count` | `3` | Number of nodes in the AKS default node pool. A minimum of 2 is recommended for high availability; higher counts raise Azure compute cost proportionally. |
| `k8s_version` | `1.35` | Kubernetes minor version (`major.minor`) for the AKS cluster. Must be supported by AKS in `azure_region`; the patch version is managed by AKS. |
| `platform_version` | `1.35.0-gke.1` | Attached-cluster platform version (the Connect agent / managed components installed on AKS). Its minor version must equal `k8s_version` or be exactly one below it. Run `gcloud container attached get-server-config --location=<gcp_location>` for the versions currently offered. |
| `vm_size` | `Standard_D2s_v3` | Azure VM SKU for the node pool (e.g. `Standard_D2s_v3` = 2 vCPU / 8 GB). Larger SKUs raise Azure cost; availability varies by region. |

---

## 5. Outputs

The deployment surfaces two output values:

| Output | Description |
|---|---|
| `deployment_id` | The resolved deployment ID — the supplied `deployment_id`, or an auto-generated random hex when none was provided. |
| `project_id` | The destination Google Cloud project ID. |

Neither identifies the cluster, so the identifiers you need to operate it must still be derived or recorded manually:

- **Attached-cluster / membership name** — the value of `cluster_name_prefix` (default `azure-aks-cluster`). Confirm the exact name with `gcloud container fleet memberships list --project "$PROJECT"`. This name is required for `get-credentials`, `describe`, and most other commands.
- **Fleet location** — the value of `gcp_location` (default `us-central1`), needed for `gcloud container attached clusters` commands.
- **Azure Resource Group** — `<cluster_name_prefix>-rg`, needed for `az` operations and manual cleanup.

Record the membership name immediately after deployment; every Day-2 and teardown command depends on it.

---

## 6. Configuration Pitfalls & Sensible Defaults

> Risk: **Critical** (data loss / outage / security) — **High** (service degraded) —
> **Medium** (cost or partial degradation) — **Low** (minor).

| Setting | Sensible value | Risk | Consequence if wrong |
|---|---|---|---|
| `client_id` / `client_secret` / `azure_tenant_id` / `subscription_id` | valid service-principal credentials, Contributor on the subscription | Critical | Missing or wrong credentials fail the apply at AKS creation; an under-privileged principal partially provisions and leaves orphaned Azure resources. The service principal needs subscription-level Contributor because the module creates the Resource Group itself. |
| `platform_version` ↔ `k8s_version` | keep the minors compatible (e.g. `1.35.0-gke.1` with `1.35`; the platform minor may also be one below) | High | An incompatible pairing fails attachment or leaves the Connect agent unhealthy, so the cluster never becomes manageable from Google Cloud. |
| `cluster_name_prefix` | set once, unique per project/subscription | High | Changing after first deploy recreates the cluster across both clouds, destroying the Azure AKS cluster and any workloads on it. Reusing a prefix for a second deployment causes resource conflicts. |
| `trusted_users` | the operators who need access | High | Omitting an operator leaves them unable to reach the cluster via the gateway; remember the deploying identity is always admin, and entries cannot be blank or duplicated. |
| `node_count` | `3` (≥2 for HA) | Medium | `1` removes high availability — a single node failure or drain takes the cluster's workloads down and can interrupt the fleet connection; very high counts inflate Azure cost. |
| `vm_size` | `Standard_D2s_v3` | Medium | Undersized SKUs cause scheduling pressure and OOM kills; oversized SKUs inflate Azure cost; some SKUs are unavailable in certain regions. |
| `azure_region` / `gcp_location` | regions that support AKS and attached clusters respectively | Medium | An unsupported region fails provisioning or attachment; mismatched regions add cross-region latency for management traffic. |
| Enabled Google Cloud APIs | leave enabled on teardown (default) | Low | The module deliberately does not disable APIs on destroy to avoid breaking other workloads in the shared project. |

---

For the Google Cloud and Azure operations referenced throughout — verifying fleet membership, connecting via the Connect gateway, exploring logs and metrics, and tearing the deployment down — see the **[AKS_GKE lab guide](https://docs.radmodules.dev/docs/labs/AKS_GKE)**.
