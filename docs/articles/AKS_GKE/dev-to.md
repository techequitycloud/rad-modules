<!--
Target:   Dev.to
Audience: Platform engineers and DevOps practitioners running Azure AKS who are curious about Google Cloud fleet management
Voice:    Hands-on, conversational, practical, real commands, show-don't-tell
Tags:     #googlecloud #azure #aks #gke #kubernetes #multicloud #devops
Goal:     Show that managing an Azure AKS cluster from a Google Cloud fleet is approachable and doesn't require migration; CTA to deploy the AKS_GKE RAD module.
-->

# Manage an Azure AKS Cluster from Google Cloud — Without Moving the Workload Off Azure

Most "multicloud Kubernetes" stories end with a migration. Someone decides the workloads should live somewhere else, and six months later they're still untangling networking. This isn't that.

The **AKS_GKE** RAD module does something narrower and far more useful for learning: it spins up a **Microsoft Azure AKS cluster**, then registers it with Google Cloud as a **GKE Attached Cluster** — a full member of a **GKE Fleet**. The cluster keeps running entirely in Azure. Google Cloud just gets a management plane over it. You end up running `kubectl` against an Azure cluster using your *Google* identity, watching its logs in Cloud Logging, and seeing it in the GKE console next to any native GKE clusters — all without touching the workloads.

It's a standalone educational module that provisions resources in **two clouds** at once. Let's look at what actually lands and how the cross-cloud trust works.

## What you get

- **An AKS cluster in Azure** — created with a system-assigned managed identity, OIDC issuer enabled, and a default node pool (3 nodes of `Standard_D2s_v3` by default), inside its own Azure Resource Group.
- **A GKE Fleet membership** — the AKS cluster registered as a GKE *Attached Cluster*, showing up in the Google Cloud Console with distribution type `aks`.
- **Connect gateway access** — run `kubectl` against the Azure cluster through Google's gateway using Google Cloud IAM. No Azure kubeconfig to distribute, no VPN, no inbound firewall rules in Azure.
- **OIDC federation** — Google Cloud validates Kubernetes tokens against the AKS OIDC issuer's public keys. No service-account keys or shared secrets cross between the clouds.
- **Centralized logging** — system-component and workload logs from AKS flow into the same project's Cloud Logging, using the same schema as GKE.
- **Centralized metrics** — Managed Service for Prometheus runs a collector on the AKS nodes and forwards Kubernetes metrics to Cloud Monitoring; the built-in GKE dashboards populate on their own.

The fun bit for a demo: a cluster physically running in Azure `westus2`, but the *operator experience* — auth, kubectl, logs, metrics, dashboards — is pure Google Cloud.

## The trick: attach, don't migrate

The mechanism that makes this work is the **GKE Connect agent**, installed onto the AKS cluster via **Helm**. On apply, the module:

1. creates the Azure Resource Group and AKS cluster,
2. grants the cluster's managed identity **Network Contributor** on the Resource Group (so AKS can manage Azure load balancers for `LoadBalancer` Services),
3. installs the Connect agent via Helm, then
4. registers the cluster as a GKE Attached Cluster and enrolls it in the fleet with logging, Managed Prometheus, and an admin-user list.

The Connect agent maintains a **persistent, encrypted, outbound** connection from AKS to Google Cloud. That's the whole reason you don't need a public AKS API endpoint or inbound rules — the cluster dials out, Google never dials in.

## Deploying it

You need **both** a Google Cloud project (billing enabled) and an Azure subscription. Azure credentials come in as four sensitive inputs — `client_id`, `client_secret`, `tenant_id`, `subscription_id` — for an Azure AD service principal with at least **Contributor on the subscription** (the module creates the Resource Group itself, so subscription-level Contributor is genuinely needed).

This module uses **direct provider auth** (`azurerm` / `google` / `helm`), not impersonation. Pass Azure credentials via the module variables / `ARM_*` environment variables — never hardcode them as defaults.

Via the launcher:

```bash
python3 rad-launcher/radlab.py \
  -m AKS_GKE -a create \
  -p my-mgmt-project -b my-mgmt-project-radlab-tfstate \
  -f /path/to/my.tfvars
```

Or straight OpenTofu/Terraform from the module directory:

```bash
cd modules/AKS_GKE
tofu init
tofu apply -var="project_id=my-gcp-project"
```

**Heads up: a first apply takes ~12–20 minutes**, and AKS provisioning in Azure is the longest phase. Be patient — most of that wait is Azure building a cluster, not Terraform spinning.

## Poke at it

The module declares **no outputs**, so write down the attached-cluster name right after deploy — it's the value of `cluster_name_prefix` (default `azure-aks-cluster`), and nearly every Day-2 command needs it. Confirm it:

```bash
gcloud container fleet memberships list --project "$PROJECT"
```

Now wire up `kubectl` through the Connect gateway and talk to an Azure cluster with your Google identity:

```bash
gcloud container fleet memberships get-credentials "$CLUSTER" --project "$PROJECT"

kubectl config current-context        # connectgateway_<project>_global_<cluster>
kubectl get nodes -o wide
kubectl get pods --all-namespaces
```

That `connectgateway_...` context is the payoff — you're hitting an AKS API server you have no direct network route to, proxied through Google Cloud IAM.

Then go look at the centralized observability:

```bash
# Logs from the Azure cluster, in Cloud Logging
gcloud logging read 'resource.labels.cluster_name="'"$CLUSTER"'"' \
  --project "$PROJECT" --limit 20

# Metrics through the gateway
kubectl top nodes
```

In the Console: **Kubernetes Engine → Clusters** shows the Azure cluster with an Azure icon and type `Attached`; **Monitoring → Dashboards** has the GKE dashboards already populating from AKS metrics.

## Access model worth understanding

Access through the gateway is two-layered, and it trips people up if they only set one half:

- A **Google Cloud IAM role** on the project (e.g. `roles/gkehub.gatewayReader` / `gatewayEditor` / `gatewayAdmin`) authorizes *traversing* the gateway.
- **Kubernetes RBAC** on the cluster authorizes the specific API actions.

Users in `trusted_users` (plus the deploying identity, always) get cluster-admin automatically. Forget to list an operator and they simply can't reach the cluster — entries must also be non-blank and unique.

## Things worth knowing before you rely on it

This is an **education and demo** module. Honest edges:

- **`platform_version` must match `k8s_version`.** The attached-component / Connect agent version (e.g. `1.34.0-gke.1`) has to be compatible with the AKS Kubernetes minor (e.g. `1.34`). Mismatch them and attachment fails or the agent stays unhealthy — the cluster never becomes manageable from Google Cloud.
- **`cluster_name_prefix` is used verbatim — and there's no deployment-ID suffix on the cluster name.** Two deployments with the same prefix in the same subscription + project will collide. Changing it after the first deploy *recreates the cluster across both clouds*, destroying the AKS cluster and anything on it. Set it once.
- **Two clouds, two bills.** Azure charges for the AKS nodes; Google Cloud charges for fleet management and observability ingestion. Cranking `node_count` or `vm_size` raises the Azure side proportionally.
- **A service-mesh sub-module ships with it but is NOT installed automatically.** Installing Cloud Service Mesh / Istio is a separate, manual step outside a standard deployment.
- **Teardown leaves the Google Cloud APIs enabled** on purpose, so a destroy doesn't break other workloads sharing the project. Destroy deregisters the cluster, removes the Connect agent, and deletes the Azure Resource Group and AKS cluster.

## Why it's a great thing to deploy

If you've got an Azure footprint and you've been wondering what "single pane of glass across clouds" actually feels like — not as a slide, as a terminal — this is the fastest honest way to find out. You keep the workload where it is, and you get Google Cloud's IAM, kubectl access, logging, and metrics layered on top of it. The hard parts (OIDC trust, the outbound Connect tunnel, the Helm agent install, the fleet registration) are handled, so you can spend your time on the concept: managing a cluster you didn't move.

Deploy it, run `gcloud container fleet memberships get-credentials` against the Azure cluster, then `kubectl get nodes`. The moment Azure nodes show up under a Google `connectgateway` context, the whole idea clicks.

👉 **AKS_GKE** lives in the RAD Lab modules catalog. Grab it, deploy it, and explore the [module deep-dive](../../modules/AKS_GKE.md) and the [hands-on lab guide](../../labs/AKS_GKE.md).
