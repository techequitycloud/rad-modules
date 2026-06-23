<!--
Target:   Reddit r/devops
Audience: Practitioners who hate marketing; want the honest what/why/gotchas on cross-cloud Kubernetes management
Voice:    Plain, no hype, first-person, discussion-starting; invites correction
Tags:     (Reddit has no tags; flair suggestion) Flair: Open Source / Tooling
Goal:     Honest writeup of an OSS reference module that attaches an Azure AKS cluster to a GKE Fleet; spark discussion, link the module.
-->

# A reference module that registers an Azure AKS cluster into a GKE Fleet — kubectl via Connect gateway with your Google identity, no migration, no VPN

Posting this because "manage clusters across clouds from one place" usually turns out to mean "migrate your clusters to our place," and this is one of the few things I've tried that actually doesn't. Not selling anything — it's an educational OSS module in the RAD Lab catalog. What it does + honest gotchas below.

**What it does**

One apply (two clouds) stands up:

- An **Azure AKS** cluster — system-assigned managed identity, OIDC issuer enabled, default node pool (3x `Standard_D2s_v3` by default), in its own Resource Group
- The cluster registered with Google Cloud as a **GKE Attached Cluster** — a real GKE **Fleet** member, shows up in the GKE console with distribution `aks`
- **GKE Connect agent** installed onto AKS via **Helm**, holding a persistent *outbound* connection to Google Cloud (no public AKS endpoint, no inbound firewall rules, no VPN)
- **Connect gateway** access — `kubectl` against the Azure cluster using your Google Cloud identity, no Azure kubeconfig handed around
- **OIDC federation** for trust — Google validates AKS-issued tokens against the cluster's public keys; no shared secrets between clouds
- Centralized **Cloud Logging** + **Managed Prometheus → Cloud Monitoring** (GKE dashboards populate on their own)

The cluster never leaves Azure. Google Cloud just gets a management plane over it.

```
gcloud container fleet memberships list --project "$PROJECT"
gcloud container fleet memberships get-credentials "$CLUSTER" --project "$PROJECT"
kubectl get nodes -o wide            # azure nodes, via connectgateway_<proj>_global_<cluster>
```

**The part that's actually nice**

You run kubectl against an Azure cluster you have no direct network route to, authenticating with Google IAM. Access is two-layered: a GCP IAM role (`gatewayReader`/`gatewayEditor`/`gatewayAdmin`) lets you traverse the gateway, K8s RBAC on the cluster authorizes the actual actions. `trusted_users` (plus the deploying identity) get cluster-admin.

**Gotchas / things I'd want to know first**

- **It's a two-cloud module.** Needs a GCP project w/ billing AND an Azure subscription. Four sensitive inputs (`client_id`/`client_secret`/`tenant_id`/`subscription_id`) for a service principal that needs **Contributor on the subscription** — the module creates the Resource Group itself, so RG-scoped isn't enough. Uses direct provider auth (azurerm/google/helm); creds via the module vars / `ARM_*` env, never hardcoded.
- **First apply is ~12–20 min**, mostly Azure building the cluster. Not Terraform hanging.
- **`platform_version` must match `k8s_version`.** Agent/attached-component version (e.g. `1.34.0-gke.1`) has to be compatible with the AKS minor (e.g. `1.34`). Mismatch = attaches but stays unhealthy/unmanageable. Easy to get wrong, annoying to debug.
- **Cluster name has no deployment-ID suffix.** `cluster_name_prefix` is used verbatim in both clouds. Two deploys with the same prefix in the same sub+project collide. Changing it after first deploy **recreates the cluster in both clouds** and nukes the AKS workloads. Set it once.
- **No outputs.** The module declares zero outputs — write down the membership name (= `cluster_name_prefix`, default `azure-aks-cluster`) right after deploy, every Day-2 + teardown command needs it.
- **Service mesh sub-module ships but is NOT auto-installed.** CSM/Istio is a separate manual step. Attachment gives you management + observability, not an east-west mesh.
- **Teardown leaves GCP APIs enabled** on purpose (shared-project safety). Destroy deregisters, removes the agent, deletes the Azure RG + cluster.

**Why bother**

It's the least hand-wavy way I've found to actually see fleet attachment work: an Azure cluster, left in Azure, operated from Google Cloud with one identity, logs and metrics centralized, trust via OIDC federation instead of shared keys. Good for learning the attached-cluster / Connect gateway model, demos, or sanity-checking whether "multicloud single pane of glass" is real before you bet an architecture on it.

Honest question for the sub: for those of you actually running clusters across clouds — is the GKE-fleet-attaches-AKS model (centralize identity/observability on GCP, leave the workload in Azure) something you'd run for real, or does the outbound Connect agent + cross-cloud control plane add more lock-in/blast-radius than it's worth vs just running two separate ops stacks? And has anyone hit the platform_version/k8s_version coupling biting them on upgrades?

Module + docs (deep-dive and a step-by-step lab) are in the RAD Lab `rad-modules` repo under `AKS_GKE`.
