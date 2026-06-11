# Multi-Cluster Bank of Anthos on GKE — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/MC_Bank_GKE)**

## Overview

**Estimated time:** 90–150 minutes (most of it the initial multi-cluster deploy)

Bank of Anthos is Google's open-source microservices banking demo. This module deploys it
across **multiple GKE clusters in multiple regions**, joined into a single **GKE Fleet**, a
**multi-primary Cloud Service Mesh**, and a **multi-cluster gateway / global load balancer** so
one public address serves the nearest healthy region. This lab walks you through the full
operational lifecycle: deploy it, reach it through the global load balancer, operate it across
several cluster contexts, observe it fleet-wide, diagnose cross-cluster issues, and tear it down.

The lab focuses on operating the **multi-cluster GKE platform and the Google Cloud services
around it**, not on banking product features. For the complete list of provisioned services and
every configuration input (organised by group), see the
[Configuration Guide](https://docs.radmodules.dev/docs/modules/MC_Bank_GKE) — this lab
deliberately does not duplicate that detail so it stays accurate over time.

## Objectives

By the end of this lab you will be able to:

- Deploy the module from the RAD platform and locate the clusters, fleet, mesh, and global load balancer it provisions.
- Reach the application through the multi-cluster gateway and confirm workloads are running on every cluster.
- Operate the deployment across multiple cluster contexts (inspect, scale, update).
- Observe the workload fleet-wide with Cloud Logging, Cloud Monitoring, the Service Mesh dashboard, and Cloud Trace.
- Diagnose the cross-cluster failure modes you are most likely to hit.
- Tear the deployment down cleanly.

## Prerequisites

- A Google Cloud project with **billing enabled** and sufficient regional quota for several GKE clusters.
- **gcloud CLI** and **kubectl** installed; `gcloud auth login` and `gcloud auth application-default login` completed.
- **Project Owner** (or equivalent) IAM on the project.
- **RAD platform access** with permission to deploy modules into the project.

This module is **standalone** — it builds its own VPC, clusters, fleet, mesh, and load balancer,
so it does not require Services_GCP or any other module to be deployed first.

Set these shell variables once. Note that this deployment has **more than one cluster**, so you
will configure and switch between a context per cluster throughout the lab:

```bash
export PROJECT="<your-gcp-project-id>"
export REGION1="us-west1"     # available_regions[0] — primary / config cluster
export REGION2="us-east1"     # available_regions[1]
export NS="bank-of-anthos"    # application namespace on every cluster

gcloud config set project "$PROJECT"
```

---

## Task 1 — Deploy the module [Automated]

1. Click **Deploy** in the RAD platform top navigation, open **Multi-Cluster Bank of Anthos (GKE)**
   from the **Platform Modules** list to start configuration, set `project_id`, and review the inputs.
   Configure only what you need — the
   [Configuration Guide](https://docs.radmodules.dev/docs/modules/MC_Bank_GKE) documents every
   input by group, with defaults. Key choices are `available_regions`, `cluster_size`,
   `create_autopilot_cluster`, and `enable_cloud_service_mesh`. Review the estimated cost (if
   credits are enabled) and click **Deploy**, which opens the deployment status page with
   real-time logs.

2. The platform creates the shared VPC, one GKE cluster per region, registers every cluster into
   a GKE Fleet, enables a fleet-wide multi-primary Cloud Service Mesh, deploys Bank of Anthos to
   all clusters, and provisions a global external load balancer with a Google-managed certificate.
   First deploys take roughly **40–60 minutes** — multi-cluster + fleet + managed mesh + global
   load balancer provisioning is inherently slow.

3. Connect to every cluster and set up a context per cluster (with the defaults there are two,
   `gke-cluster-1` and `gke-cluster-2`):

   ```bash
   gcloud container clusters get-credentials gke-cluster-1 --region "$REGION1" --project "$PROJECT"
   gcloud container clusters get-credentials gke-cluster-2 --region "$REGION2" --project "$PROJECT"

   kubectl config rename-context "gke_${PROJECT}_${REGION1}_gke-cluster-1" cluster1
   kubectl config rename-context "gke_${PROJECT}_${REGION2}_gke-cluster-2" cluster2
   kubectl config get-contexts

   kubectl --context cluster1 get nodes
   kubectl --context cluster2 get nodes
   ```

---

## Task 2 — Access & verify [Manual]

1. **Confirm the fleet and the workload on each cluster.** Pods in the `bank-of-anthos`
   namespace should be `2/2` ready (application container + Envoy sidecar) on every cluster:

   ```bash
   gcloud container fleet memberships list --project "$PROJECT"
   kubectl --context cluster1 get pods -n "$NS"
   kubectl --context cluster2 get pods -n "$NS"
   ```

   Note that the `accounts-db` and `ledger-db` StatefulSets appear **only on the primary cluster**
   (`cluster1`) — that is by design; non-primary clusters use the primary's databases.

2. **Reach the app through the multi-cluster gateway.** Find the global IP, then browse to the
   `sslip.io` URL:

   ```bash
   GLOBAL_IP=$(gcloud compute addresses list --global --project "$PROJECT" \
     --filter="name~bank" --format="value(address)")
   echo "App: https://boa.${GLOBAL_IP}.sslip.io"
   curl -sk "https://boa.${GLOBAL_IP}.sslip.io" | grep -i "<title>"
   ```

   The Google-managed certificate can take **10–60 minutes** to become `Active` after first
   deploy — until then HTTPS may warn or fail. Check its status with:

   ```bash
   kubectl --context cluster1 get managedcertificate -n "$NS" \
     -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.certificateStatus}{"\n"}{end}'
   ```

   Log in with the demo credentials shown on the Bank of Anthos sign-in page.

3. **Confirm the mesh spans both clusters** and the global load balancer has healthy backends in
   each region:

   ```bash
   gcloud container fleet mesh describe --project "$PROJECT"
   BACKEND=$(gcloud compute backend-services list --global --project "$PROJECT" \
     --filter="name~bank-of-anthos" --format="value(name)" | head -1)
   gcloud compute backend-services get-health "$BACKEND" --global --project "$PROJECT"
   ```

   You should see one Network Endpoint Group per cluster, each reporting healthy backends.

---

## Task 3 — Operate (Day-2) [Manual]

Day-2 work here means working across **multiple cluster contexts**.

1. **Inspect the workload on each cluster:**

   ```bash
   kubectl --context cluster1 get deploy,pods,svc -n "$NS"
   kubectl --context cluster2 get deploy,pods,svc -n "$NS"
   ```

2. **Re-scale or re-shape the platform** by changing inputs (`cluster_size`, `available_regions`,
   `release_channel`, mesh on/off) and clicking **Update** on the deployment details page. The
   module owns the cluster set, fleet, mesh, and ingress — adding or removing clusters is a
   configuration change, not a manual `gcloud`/`kubectl` operation (manual changes would be
   reconciled away on the next apply). Treat the primary cluster (`cluster1`) as the data tier
   when planning changes.

3. **Inspect the multi-cluster ingress and services** from the config cluster:

   ```bash
   kubectl --context cluster1 get multiclusteringress,multiclusterservice -n "$NS"
   kubectl --context cluster1 describe multiclusterservice bank-of-anthos-mcs -n "$NS"
   ```

4. **Apply mesh traffic policy** (optional) — because the mesh is fleet-wide, Istio resources
   such as `VirtualService`, `DestinationRule`, `PeerAuthentication`, and `AuthorizationPolicy`
   can be applied per cluster to shape or secure traffic. Apply the same resource on each cluster
   you want it to take effect on.

---

## Task 4 — Observe [Manual]

1. **Logs across clusters** — Cloud Logging tags each entry with its cluster, so you can compare
   regions in one query:

   ```bash
   gcloud logging read \
     'resource.type="k8s_container" AND resource.labels.namespace_name="bank-of-anthos"' \
     --project "$PROJECT" --limit 20 \
     --format="table(timestamp,resource.labels.cluster_name,resource.labels.location)"
   ```

   Or per cluster directly:

   ```bash
   kubectl --context cluster1 logs -n "$NS" -l app=frontend --tail=50
   kubectl --context cluster2 logs -n "$NS" -l app=frontend --tail=50
   ```

2. **Service Mesh dashboard** — open Kubernetes Engine → Service Mesh to see the live, combined
   service topology, golden signals (latency, traffic, errors, saturation), and mTLS status across
   all clusters. The continuous load generator keeps these populated.

3. **Monitoring & Prometheus** — review the GKE dashboards (Monitoring → Dashboards → GKE) for
   per-cluster node and pod utilisation, and compare resource use side by side:

   ```bash
   kubectl --context cluster1 top pods -n "$NS"
   kubectl --context cluster2 top pods -n "$NS"
   ```

4. **Cloud Trace** — open Trace → Trace List to follow a request across the microservices; each
   inbound request generates a trace spanning every downstream hop.

---

## Task 5 — Troubleshoot [Manual]

Durable techniques for the cross-cluster failure modes you are most likely to hit. These are
platform-level diagnostics and do not change with application releases.

- **Pods not `2/2` (no sidecar):** confirm the namespace injection label and mesh status:
  ```bash
  kubectl --context cluster1 get ns "$NS" --show-labels      # expect istio.io/rev=asm-managed
  gcloud container fleet mesh describe --project "$PROJECT"   # control/data plane ACTIVE per membership
  ```
- **One region serving, the other not:** check that cluster's backend NEG health and pods. The
  global load balancer automatically stops routing to a cluster whose backends are unhealthy:
  ```bash
  kubectl --context cluster2 get pods -n "$NS"
  gcloud compute backend-services get-health "$BACKEND" --global --project "$PROJECT"
  ```
- **App reachable but data operations fail on a non-primary cluster:** remember the databases live
  only on the primary cluster (`cluster1`). Confirm the DB pods are healthy there, and that the
  primary cluster and its region are up:
  ```bash
  kubectl --context cluster1 get statefulset,pods -n "$NS" -l 'app in (accounts-db,ledger-db)'
  ```
- **HTTPS warnings / no certificate:** the managed certificate is still provisioning (10–60 min).
  Check `status.certificateStatus` on the `ManagedCertificate`; `Provisioning` is normal early on.
- **Fleet membership not `READY` / mesh not configuring:** inspect membership and feature state:
  ```bash
  gcloud container fleet memberships list --project "$PROJECT"
  gcloud container fleet features list --project "$PROJECT"
  ```
- **Cross-cluster mesh auth issues:** all clusters must share the same trust domain
  (`<project>.svc.id.goog`); confirm via `gcloud container fleet mesh describe`.

See the Configuration Guide's *Configuration Pitfalls* section for setting-specific gotchas.

---

## Task 6 — Tear down [Automated]

On the **Deployments** page, open the deployment and click the **Trash** icon (**Delete**).
Delete runs `terraform destroy` and is irreversible (the deployment record is retained for
history). Tear-down removes everything the module created across every cluster — the Bank of
Anthos workloads and namespaces, the Multi-Cluster Ingress/Service resources and global load
balancer, the fleet memberships and mesh feature, all GKE clusters, and the shared VPC and its
networking. The destroy runs ordered cleanup so multi-cluster ingress, mesh, and fleet state are
removed before the clusters and VPC, avoiding orphaned Cloud resources.

If a deployment is stuck and the RAD platform can no longer manage it (for example after manual
changes that conflict with the Terraform state), use **Purge** instead — it removes the deployment
from RAD's records **without** destroying the cloud resources (it makes RAD forget the project).
After a Purge, any clusters, fleet memberships, load balancer, and VPC remain in the project and
must be cleaned up manually.

---

## Summary

| Task | Type | Outcome |
|---|---|---|
| 1 — Deploy | Automated | Module creates the VPC, multiple GKE clusters, fleet, multi-primary mesh, Bank of Anthos, and the global load balancer |
| 2 — Access & verify | Manual | Reach the app via the multi-cluster gateway; confirm pods on each cluster, MCS service, and mesh endpoints fleet-wide |
| 3 — Operate | Manual | Inspect and re-shape the platform across multiple cluster contexts |
| 4 — Observe | Manual | Aggregate Cloud Logging; review the Service Mesh dashboard, Monitoring/Prometheus, and Cloud Trace |
| 5 — Troubleshoot | Manual | Diagnose sidecar, per-region backend, primary-cluster data-tier, certificate, and fleet/mesh issues |
| 6 — Tear down | Automated | Delete (Trash) removes all module resources across every cluster; Purge removes RAD's record without destroying resources |
