# Bank of Anthos on GKE — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/Bank_GKE)**

## Overview

**Estimated time:** 60–120 minutes

Bank of Anthos is Google Cloud's open-source reference banking application — a polyglot
microservices demo (Python and Java services with two PostgreSQL databases) that mimics a
retail bank with accounts, a transaction ledger, and a web frontend. This lab takes you
through the full operational lifecycle of the **Bank of Anthos on GKE** module on Google
Cloud: deploy it, access and verify it, run it day-to-day, observe it, diagnose common
problems, and tear it down.

The lab focuses on operating the **GKE module and the Google Cloud platform** — the cluster,
the managed service mesh, the fleet, and observability — not on banking product features.
For the complete list of provisioned services and every configuration input (organised by
group), see the
[Configuration Guide](https://docs.radmodules.dev/docs/modules/Bank_GKE) — this lab
deliberately does not duplicate that detail so it stays accurate over time.

## Objectives

By the end of this lab you will be able to:

- Deploy the module from the RAD platform and locate the resources it provisions.
- Connect to the GKE cluster, reach the Bank of Anthos UI, and confirm pods and mesh sidecars are running.
- Perform day-2 operations — inspect, scale, update, and roll workloads.
- Observe the workload with the service mesh dashboards, Cloud Monitoring, and Cloud Logging.
- Diagnose and resolve the most common deployment and runtime issues.
- Tear the deployment down cleanly.

## Prerequisites

- A Google Cloud project with **billing enabled** (this is a standalone module — there is no
  separate platform module to deploy first).
- **gcloud CLI** and **kubectl** installed; `gcloud auth login` and
  `gcloud auth application-default login` completed.
- **Project Owner** (or equivalent) IAM on the project.
- **RAD platform access** with permission to deploy modules into the project.

Set these shell variables once; every task below reuses them:

```bash
export PROJECT="<your-gcp-project-id>"
export REGION="us-central1"          # the region you deploy into
export CLUSTER="gke-cluster"         # matches the gke_cluster input
export NS="bank-of-anthos"           # the application namespace
```

---

## Task 1 — Deploy the module [Automated]

1. Click **Deploy** in the RAD platform top navigation, open **Bank of Anthos (GKE)** from the
   **Platform Modules** list to start configuration, set `project_id`, and review the inputs.
   Configure only what you need — the
   [Configuration Guide](https://docs.radmodules.dev/docs/modules/Bank_GKE) documents every
   input by group, with defaults. Review the estimated cost (if credits are enabled) and click
   **Deploy**, which opens the deployment status page with real-time logs.

2. The platform creates a dedicated VPC and subnet, a GKE Autopilot cluster, registers the
   cluster in the fleet, enables Cloud Service Mesh, then deploys the Bank of Anthos `v0.6.7`
   workloads into the `bank-of-anthos` namespace and configures Cloud Monitoring services and
   SLOs. Because the apply waits for the mesh control plane to become active before deploying
   the application, first deploys take roughly **30–45 minutes**.

3. Connect to the cluster and confirm the namespace exists:

   ```bash
   gcloud container clusters get-credentials "$CLUSTER" --region="$REGION" --project="$PROJECT"
   kubectl get ns "$NS"
   kubectl get all -n "$NS"
   ```

---

## Task 2 — Access & verify [Manual]

1. Confirm every workload is running with its mesh sidecar. Each pod should show **2/2 READY**
   (application container plus the Envoy sidecar):

   ```bash
   kubectl get pods -n "$NS"
   kubectl get namespace "$NS" --show-labels      # expect istio.io/rev=asm-managed
   ```

2. Find the frontend's external address and reach the Bank of Anthos UI in a browser. The
   frontend is exposed via a LoadBalancer Service over plain HTTP:

   ```bash
   FRONTEND_IP=$(kubectl get svc frontend -n "$NS" \
     -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   echo "Open: http://${FRONTEND_IP}"
   curl -sI "http://${FRONTEND_IP}/" | head -1     # expect HTTP 200
   ```

   Open `http://${FRONTEND_IP}` and sign in with the built-in demo credentials
   (`testuser` / `password`), then view a balance, make a deposit, and transfer funds.

3. Confirm the managed mesh is active for the cluster:

   ```bash
   gcloud container fleet mesh describe --project="$PROJECT"
   # Look for controlPlaneManagement.state: ACTIVE under the cluster's membership
   ```

---

## Task 3 — Operate & keep it running (Day-2) [Manual]

1. **Inspect the workloads** — deployments, pods, StatefulSets, and persistent volumes:

   ```bash
   kubectl get deploy,statefulset,pods,pvc -n "$NS"
   kubectl describe deploy frontend -n "$NS"
   ```

2. **Scale a service** to add capacity, and watch the rollout:

   ```bash
   kubectl scale deployment balancereader -n "$NS" --replicas=3
   kubectl get pods -n "$NS" -l app=balancereader -w
   ```

3. **Trigger a rolling update** and observe pods cycle one at a time:

   ```bash
   kubectl rollout restart deployment/frontend -n "$NS"
   kubectl rollout status deployment/frontend -n "$NS"
   ```

4. **Apply infrastructure-level changes** (cluster mode, region, mesh on/off, monitoring
   on/off, application on/off) by editing the inputs and clicking **Update** on the deployment
   details page — the module owns the cluster and feature configuration, so these are
   configuration changes rather than manual `gcloud`/`kubectl` edits.

5. **Review fleet and membership state:**

   ```bash
   kubectl get nodes -o wide
   gcloud container fleet memberships list --project="$PROJECT"
   ```

---

## Task 4 — Observe: mesh telemetry, dashboards & logs [Manual]

1. **Service mesh telemetry** — open Kubernetes Engine → Service Mesh to see the live service
   topology, request rates, error rates, and P99 latency per service. The `loadgenerator`
   service drives continuous synthetic traffic so these graphs always have data.

2. **Monitoring & SLOs** — open Monitoring → Services to see each Bank of Anthos microservice
   registered as a monitored service, each with a CPU-limit-utilisation SLO. Inspect the SLI
   value, error budget, and burn rate per service:

   ```bash
   gcloud monitoring services list --project="$PROJECT"
   ```

3. **Logs** — from `kubectl` or the Logs Explorer:

   ```bash
   kubectl logs -n "$NS" deploy/frontend --tail=50
   ```

   Logs Explorer filter:
   `resource.type="k8s_container" AND resource.labels.namespace_name="bank-of-anthos"`.

4. **Distributed traces** — open Trace → Trace list. The mesh sidecars export traces
   automatically, so a login or transfer request appears as a multi-service waterfall
   (`frontend` → `userservice`/`ledgerwriter` → databases).

---

## Task 5 — Troubleshoot & debug [Manual]

Durable techniques for the failure modes you are most likely to hit. These are platform-level
diagnostics and do not change with Bank of Anthos releases.

- **Pod not Ready / CrashLoopBackOff:** inspect events and logs:
  ```bash
  kubectl describe pod -n "$NS" <pod>          # Events section shows scheduling/probe/mount errors
  kubectl logs -n "$NS" <pod> --previous       # logs from the crashed container
  ```
- **Pod stuck Pending:** on Autopilot this is usually regional quota or an unsupported pod
  spec. Check `kubectl describe pod` events and try a different region if quota is the cause.
- **Pods show 1/1 instead of 2/2 (no sidecar):** confirm the namespace label
  `istio.io/rev=asm-managed` is present and that the mesh is `ACTIVE`
  (`gcloud container fleet mesh describe`). Restart the affected pods after the mesh is ready.
- **Frontend unreachable / no external IP:** confirm the `frontend` Service has an assigned
  LoadBalancer IP (`kubectl get svc frontend -n "$NS"`) and that the HTTP firewall rule exists.
- **Mesh never becomes active during deploy:** mesh provisioning is asynchronous and can take
  10–20 minutes; if the apply timed out, re-running the deployment usually completes it once the
  fleet feature has settled.

See the Configuration Guide's *Configuration Pitfalls* section for setting-specific gotchas.

---

## Task 6 — Tear down [Automated]

On the **Deployments** page, open the deployment and click the **Trash** icon (**Delete**).
Delete runs `terraform destroy` and is irreversible (the deployment record is retained for
history). This removes everything the module created — the Bank of Anthos workloads and
namespace (including all `accounts-db` and `ledger-db` data), the GKE cluster, the fleet
membership and Cloud Service Mesh feature, the monitoring services and SLOs, the reserved
static IP, and the VPC with its subnet, Cloud NAT, router, and firewall rules.

If a deployment is stuck and the RAD platform can no longer manage it (for example after manual
changes that conflict with the Terraform state), use **Purge** instead — it removes the
deployment from RAD's records **without** destroying the cloud resources (it makes RAD forget
the project). After a purge, clean up any remaining resources manually.

---

## Summary

| Task | Type | Outcome |
|---|---|---|
| 1 — Deploy | Automated | Module creates the VPC, GKE cluster, fleet membership, mesh, and deploys Bank of Anthos |
| 2 — Access & verify | Manual | Reach the UI via the LoadBalancer IP; confirm pods are 2/2 and the mesh is active |
| 3 — Operate | Manual | Inspect workloads, scale, roll, and apply config changes via Update |
| 4 — Observe | Manual | Review mesh telemetry, Cloud Monitoring SLOs, logs, and traces |
| 5 — Troubleshoot | Manual | Diagnose pod, sidecar-injection, networking, and mesh-readiness issues |
| 6 — Tear down | Automated | Delete (Trash) destroys all module resources; Purge removes it from RAD only |
