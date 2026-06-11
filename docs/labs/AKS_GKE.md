# Azure AKS attached to a Google Cloud Fleet — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/AKS_GKE)**

## Overview

**Estimated time:** 45–90 minutes

This lab takes you through the full operational lifecycle of the **Azure AKS attached to a
Google Cloud Fleet** module on the RAD platform. The module creates a Microsoft Azure
Kubernetes Service (AKS) cluster and registers it with Google Cloud as a **GKE Attached
Cluster** — a full member of a **GKE Fleet**. From that point on, the Azure cluster can be
accessed, observed, and governed from Google Cloud through the **Connect gateway**, **Cloud
Logging**, and **Cloud Monitoring**, all without leaving the Google Cloud Console and without
migrating the workloads that run in Azure.

This is a **two-cloud** module: it provisions resources in Azure (the Resource Group and AKS
cluster) and in Google Cloud (the fleet membership and managed observability). You will deploy
it, verify the cluster is registered and reachable through the gateway, operate it day-to-day,
observe it, diagnose common problems, and tear it down. The lab focuses on operating the module
and the Google Cloud platform — for the full list of provisioned services and every
configuration input (organised by group), see the
[Configuration Guide](https://docs.radmodules.dev/docs/modules/AKS_GKE), which this lab
deliberately does not duplicate.

## Objectives

By the end of this lab you will be able to:

- Deploy the module from the RAD platform and locate what it provisions across both clouds.
- Verify the AKS cluster is registered in the fleet and reach it via the Connect gateway.
- Perform day-2 operations — inspect the cluster, manage access, and upgrade the platform version.
- Observe the cluster with Cloud Logging and Cloud Monitoring.
- Diagnose and resolve the most common attachment and connectivity issues.
- Tear the deployment down cleanly.

## Prerequisites

- A **Google Cloud project** with **billing enabled** and Owner (or equivalent) IAM on it.
- An **Azure subscription** and an **Azure AD service principal** with at least `Contributor`
  rights on that subscription. Collect its **Client ID**, **Client Secret**, **Tenant ID**,
  and **Subscription ID** before deploying.
- **gcloud CLI** and **kubectl** installed; `gcloud auth login` and
  `gcloud auth application-default login` completed.
- The **`az` (Azure) CLI** installed, for inspecting the AKS cluster directly in Azure.
- **RAD platform access** with permission to deploy modules into the project.

Set these shell variables once; every task below reuses them:

```bash
export PROJECT="<your-gcp-project-id>"
export GCP_LOCATION="us-central1"          # fleet region (gcp_location)
export CLUSTER="azure-aks-cluster"         # cluster_name_prefix; confirm the exact name in Task 2

# Azure service principal (for the optional az CLI checks)
export ARM_CLIENT_ID="<azure-client-id>"
export ARM_CLIENT_SECRET="<azure-client-secret>"
export ARM_TENANT_ID="<azure-tenant-id>"
export ARM_SUBSCRIPTION_ID="<azure-subscription-id>"
```

---

## Task 1 — Deploy the module [Automated]

1. Click **Deploy** in the RAD platform top navigation, open **Azure AKS attached to a Google
   Cloud Fleet** from the **Platform Modules** list to start configuration, and set
   `project_id`. Provide the four required Azure credentials (`client_id`, `client_secret`,
   `tenant_id`, `subscription_id`) and add yourself to `trusted_users` if you want explicit
   cluster-admin (the deploying identity is granted admin automatically). Configure only what
   you need — the
   [Configuration Guide](https://docs.radmodules.dev/docs/modules/AKS_GKE) documents every
   input by group, with defaults. Review the estimated cost (if credits are enabled) and click
   **Deploy**, which opens the deployment status page with real-time logs.

2. The platform creates the Azure Resource Group and AKS cluster, installs the GKE Connect
   agent onto it, then registers the cluster as a GKE Attached Cluster and enrols it in the
   fleet with managed logging and Managed Prometheus. First deploys take roughly **12–20
   minutes** — AKS provisioning in Azure dominates.

3. When the deployment completes, set `CLUSTER` to the `cluster_name_prefix` you used
   (default `azure-aks-cluster`) and confirm the registration:

   ```bash
   gcloud container fleet memberships list --project "$PROJECT"
   ```

---

## Task 2 — Access & verify [Manual]

1. Confirm the cluster is registered in the fleet and the membership is ready:

   ```bash
   gcloud container fleet memberships describe "$CLUSTER" --project "$PROJECT"
   gcloud container attached clusters describe "$CLUSTER" \
     --location "$GCP_LOCATION" --project "$PROJECT"
   ```

   In the Console, open **Kubernetes Engine → Clusters** and confirm the Azure cluster appears
   with type `Attached`, and **Kubernetes Engine → Fleet** shows it as a member.

2. Configure `kubectl` through the Connect gateway and reach the cluster — note this uses your
   Google Cloud identity, with no Azure credentials or VPN:

   ```bash
   gcloud container fleet memberships get-credentials "$CLUSTER" --project "$PROJECT"

   kubectl config current-context        # connectgateway_<project>_global_<cluster>
   kubectl get nodes -o wide             # AKS nodes, reachable through the gateway
   kubectl get namespaces
   kubectl get pods -n gke-connect       # the Connect agent should be Running
   ```

3. Confirm your access level:

   ```bash
   kubectl auth can-i list pods --all-namespaces     # expect: yes
   ```

---

## Task 3 — Operate (Day-2) [Manual]

1. **Inspect the cluster** through the gateway — nodes, namespaces, and the Connect agent:

   ```bash
   kubectl get nodes -o wide
   kubectl get pods --all-namespaces
   kubectl describe pod -n gke-connect -l app=gke-connect-agent
   ```

2. **Grant a colleague access** — a two-layer model (Google Cloud IAM to traverse the gateway,
   Kubernetes RBAC for cluster actions):

   ```bash
   gcloud projects add-iam-policy-binding "$PROJECT" \
     --member="user:colleague@example.com" --role="roles/gkehub.gatewayReader"
   kubectl create clusterrolebinding colleague-view \
     --clusterrole=view --user="colleague@example.com"
   ```

3. **Upgrade the platform version** by changing the `platform_version` input and clicking
   **Update** on the deployment details page. This updates only the attached-cluster
   registration / Connect agent — the AKS cluster itself is not affected. To resize the node
   pool, change `node_count` or `vm_size` and **Update**.

4. **Inspect the AKS cluster directly in Azure** (optional):

   ```bash
   az login --service-principal \
     --username "$ARM_CLIENT_ID" --password "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID"
   az aks list --subscription "$ARM_SUBSCRIPTION_ID" --output table
   ```

---

## Task 4 — Observe [Manual]

1. **Logs** — system-component and workload logs from AKS land in Cloud Logging with the same
   schema as GKE:

   ```bash
   gcloud logging read 'resource.labels.cluster_name="'"$CLUSTER"'"' \
     --project "$PROJECT" --limit 20
   ```

   Logs Explorer filter:
   `resource.labels.cluster_name="<cluster-name>"`.

2. **Metrics** — Managed Prometheus forwards Kubernetes metrics to Cloud Monitoring:

   ```bash
   gcloud monitoring metrics list \
     --filter='metric.type=starts_with("kubernetes.io/node")' --project "$PROJECT"
   kubectl top nodes
   ```

   In the Console, open **Monitoring → Dashboards** and review the built-in **GKE** dashboards,
   which populate automatically for the attached cluster, or **Monitoring → Metrics Explorer**
   and filter a `kubernetes.io/...` metric by `cluster_name`.

---

## Task 5 — Troubleshoot [Manual]

Durable techniques for the failure modes you are most likely to hit. These are platform-level
diagnostics and do not change with cluster releases.

- **Membership not `READY` / cluster not appearing:** confirm attachment completed and the
  Connect agent is healthy:
  ```bash
  gcloud container fleet memberships describe "$CLUSTER" --project "$PROJECT"
  kubectl get pods -n gke-connect
  kubectl logs -n gke-connect -l app=gke-connect-agent --tail=100
  ```
- **Attachment failed at deploy:** the most common cause is a `platform_version` whose
  major.minor does not match `k8s_version`. Verify the supported pairings:
  ```bash
  gcloud container attached get-server-config --location "$GCP_LOCATION" --project "$PROJECT"
  ```
- **Azure provisioning failed:** confirm the service-principal credentials are correct and hold
  subscription-level `Contributor` (the module creates the Resource Group itself). A wrong VM
  SKU for the chosen `azure_region` also fails node-pool creation.
- **`kubectl` access denied through the gateway:** check both layers — the Google Cloud IAM
  gateway role on the project, and the Kubernetes RBAC binding on the cluster:
  ```bash
  kubectl auth can-i list pods --all-namespaces
  gcloud logging read 'protoPayload.serviceName="connectgateway.googleapis.com"' \
    --project "$PROJECT" --limit 10
  ```
- **Transient "API not enabled" right after first deploy:** the enabled APIs need a short
  propagation window. Wait about a minute and retry.

See the Configuration Guide's *Configuration Pitfalls* section for setting-specific gotchas.

---

## Task 6 — Tear down [Automated]

On the **Deployments** page, open the deployment and click the **Trash** icon (**Delete**).
Delete runs `terraform destroy` and is irreversible (the deployment record is retained for
history). This deregisters the cluster from the fleet, removes the Connect agent, and deletes
the Azure Resource Group and AKS cluster across both clouds. The Google Cloud APIs the module
enabled are intentionally left enabled so other workloads in the project are not disrupted.

If a deployment is stuck and the RAD platform can no longer manage it (for example after manual
changes that conflict with the Terraform state), use **Purge** instead — it removes the
deployment from RAD's records **without** destroying the cloud resources. After a purge, clean
up the Azure Resource Group (`az group delete --name "$CLUSTER-rg"`) and the fleet membership
manually so they do not linger.

After teardown, remove the stale `kubectl` context if you configured the gateway:

```bash
kubectl config delete-context "connectgateway_${PROJECT}_global_${CLUSTER}"
```

---

## Summary

| Task | Type | Outcome |
|---|---|---|
| 1 — Deploy | Automated | Module creates the Azure AKS cluster and registers it as a fleet member with managed logging and metrics |
| 2 — Access & verify | Manual | Membership is `READY`; cluster reachable via the Connect gateway with `kubectl get nodes` |
| 3 — Operate | Manual | Inspect the cluster, grant gateway + RBAC access, upgrade the platform version, resize the node pool |
| 4 — Observe | Manual | Query AKS logs in Cloud Logging; review Kubernetes metrics and GKE dashboards in Cloud Monitoring |
| 5 — Troubleshoot | Manual | Diagnose membership, attachment, Azure-credential, gateway-access, and API-propagation issues |
| 6 — Tear down | Automated | Delete (Trash) destroys both Azure and Google Cloud resources; Purge removes from RAD without destroying |
