# Istio on GKE — Lab Guide

📖 **[Configuration Guide](https://docs.radmodules.dev/docs/modules/Istio_GKE)**

## Overview

**Estimated time:** 45–90 minutes

Istio is the de facto open-source **service mesh** — a transparent infrastructure layer that manages, secures, and observes service-to-service traffic in a Kubernetes cluster without any application code changes. This lab takes you through the full operational lifecycle of the **Istio on GKE** module on Google Cloud: deploy it, verify the mesh is installed and workloads can be enrolled, operate it day-to-day, observe it, diagnose common problems, and tear it down.

The module installs **open-source Istio** (via `istioctl`) onto a **GKE Standard** cluster in one of two data-plane modes — **sidecar** (Envoy per pod) or **ambient** (per-node ztunnel) — together with the Prometheus, Grafana, Jaeger, and Kiali observability stack.

This lab focuses on operating the **module and the Google Cloud platform**, not on every Istio feature. For the complete list of provisioned services and every configuration input (organised by group), see the [Configuration Guide](https://docs.radmodules.dev/docs/modules/Istio_GKE) — this lab deliberately does not duplicate that detail so it stays accurate over time.

## Objectives

By the end of this lab you will be able to:

- Deploy the module from the RAD platform and locate the resources it provisions.
- Connect to the GKE cluster and confirm the mesh is installed and healthy.
- Enrol a workload into the mesh and verify sidecar vs ambient behaviour.
- Perform day-2 operations — inspect the control plane, the Ingress Gateway, and the observability tools.
- Observe the mesh with Cloud Logging, Cloud Monitoring, and the in-cluster Istio tooling.
- Diagnose and resolve the most common deployment and runtime issues.
- Tear the deployment down cleanly.

## Prerequisites

- A Google Cloud project with **billing enabled**.
- **gcloud CLI** and **kubectl** installed; `gcloud auth login` and `gcloud auth application-default login` completed.
- **istioctl** installed locally (or use the copy the module downloads to the deploy host) — `curl -L https://istio.io/downloadIstio | sh -`.
- **Project Owner** (or `container.admin` + `compute.networkAdmin` + `iam.serviceAccountAdmin`) IAM on the project.
- **RAD platform access** with permission to deploy modules into the project.

Set these shell variables once; every task below reuses them:

```bash
export PROJECT="<your-gcp-project-id>"
export REGION="us-central1"           # the region you deploy into
export CLUSTER="gke-cluster"          # matches the gke_cluster input
```

---

## Task 1 — Deploy the module [Automated]

1. Click **Deploy** in the RAD platform top navigation, open **Istio (GKE)** from the **Platform Modules** list to start configuration, set `project_id`, and review the inputs. The key choices are `install_ambient_mesh` (`false` for sidecar mode, `true` for ambient mode) and `istio_version`. Configure only what you need — the [Configuration Guide](https://docs.radmodules.dev/docs/modules/Istio_GKE) documents every input by group, with defaults. Review the estimated cost (if credits are enabled) and click **Deploy**, which opens the deployment status page with real-time logs.

2. The platform creates a VPC and Cloud NAT, provisions a GKE Standard cluster (2 preemptible nodes), then runs the Istio installation step: it downloads `istioctl`, installs Istio with the selected profile, labels the `default` namespace for mesh enrolment, and installs the Prometheus, Grafana, Jaeger, and Kiali add-ons. First deploys take roughly **15–25 minutes** (cluster creation and the mesh install dominate).

3. Connect to the cluster (the `cluster_credentials_cmd` output gives you the exact command):

   ```bash
   gcloud container clusters get-credentials "$CLUSTER" --region "$REGION" --project "$PROJECT"
   kubectl get nodes -o wide
   kubectl get all -n istio-system
   ```

---

## Task 2 — Access & verify [Manual]

1. Confirm the control plane and observability stack are running:

   ```bash
   kubectl get pods -n istio-system
   istioctl version
   istioctl verify-install
   istioctl proxy-status            # proxies synced to istiod
   ```

2. Confirm the data-plane mode that was installed:

   ```bash
   # Sidecar mode — default namespace labelled istio-injection=enabled
   kubectl get namespace default --show-labels | grep istio-injection

   # Ambient mode — default namespace labelled istio.io/dataplane-mode=ambient
   kubectl get namespace default --show-labels | grep dataplane-mode
   kubectl get daemonset ztunnel -n istio-system           # ambient only
   ```

3. Find the Ingress Gateway's external IP (do not rely on the `external_ip` output — read it from the Service):

   ```bash
   INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system \
     -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   echo "Ingress Gateway IP: ${INGRESS_IP}"   # may take 1–2 minutes to appear
   ```

4. The module installs the mesh but **does not deploy a sample app**. Enrol a workload to verify enrolment works. The `default` namespace is already labelled, so deploy the Istio Bookinfo sample (bundled in the downloaded Istio release, or pulled directly):

   ```bash
   kubectl apply -n default \
     -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/bookinfo/platform/kube/bookinfo.yaml

   # Sidecar mode: pods show 2/2 (app + istio-proxy). Ambient mode: pods show 1/1.
   kubectl get pods -n default
   ```

---

## Task 3 — Operate & keep it running (Day-2) [Manual]

1. **Inspect the control plane and gateway:**

   ```bash
   kubectl get deploy,svc,hpa -n istio-system
   kubectl describe deploy istiod -n istio-system
   istioctl proxy-status
   ```

2. **Change the mode or Istio version** by editing `install_ambient_mesh` or `istio_version` and clicking **Update** on the deployment details page. The module owns the install, so this is a configuration change. Note that switching data-plane mode is a reinstall — plan for a maintenance window.

3. **Enforce strict mTLS** once all workloads in a namespace are enrolled, then verify:

   ```bash
   kubectl apply -f - <<'EOF'
   apiVersion: security.istio.io/v1
   kind: PeerAuthentication
   metadata:
     name: default
     namespace: default
   spec:
     mtls:
       mode: STRICT
   EOF
   kubectl get peerauthentication -n default
   ```

4. **Inspect proxy/data-plane configuration:**

   ```bash
   # Sidecar mode
   istioctl proxy-config all <pod> -n default
   # Ambient mode
   istioctl ztunnel-config workloads
   ```

---

## Task 4 — Observe: Logging & Monitoring [Manual]

1. **In-cluster observability** — port-forward the add-ons (they are not exposed externally):

   ```bash
   kubectl port-forward svc/kiali 20001:20001 -n istio-system      # http://localhost:20001 — service graph + mTLS padlocks
   kubectl port-forward svc/grafana 3000:3000 -n istio-system      # http://localhost:3000 — Istio dashboards
   kubectl port-forward svc/tracing 16686:80 -n istio-system       # Jaeger — distributed traces
   kubectl port-forward svc/prometheus 9090:9090 -n istio-system   # raw metrics / PromQL
   ```

2. **Cloud Logging** — query the mesh control plane and cluster logs:

   ```bash
   gcloud logging read 'resource.type="k8s_container" AND resource.labels.namespace_name="istio-system"' \
     --project "$PROJECT" --limit 50
   ```

3. **Cloud Monitoring** — open the GKE / Kubernetes dashboards for node and pod CPU/memory, restart counts, and request metrics. Istio metrics (e.g. `istio_requests_total`) are also available via Managed Prometheus in **Monitoring → Metrics Explorer (PromQL)**.

---

## Task 5 — Troubleshoot & debug [Manual]

Durable techniques for the failure modes you are most likely to hit. These are platform-level diagnostics and do not change with Istio releases.

- **Ingress Gateway has no external IP:** it can take 1–2 minutes; if it stays `<pending>`, check `kubectl describe svc istio-ingressgateway -n istio-system` and the project's load-balancer quota.
- **Istio install failed during deploy:** review the deployment status-page logs. The most common cause is an invalid `istio_version` (the `istioctl` download fails) or nodes not becoming Ready in time (preemptible nodes were reclaimed). Re-run **Update** after fixing the version.
- **Pod has no sidecar (sidecar mode):** confirm the namespace label `istio-injection=enabled` and remember that **existing pods must be restarted** (`kubectl rollout restart`) to receive a sidecar.
- **Workload not enrolled (ambient mode):** confirm `istio.io/dataplane-mode=ambient` on the namespace and that the `ztunnel` DaemonSet has a pod on every node (`kubectl get pods -n istio-system -l app=ztunnel -o wide`).
- **mTLS / connectivity issues:** run `istioctl analyze -A` for config validation and `istioctl proxy-status` to confirm proxies are synced to `istiod`.
- **Pod CrashLoopBackOff:** `kubectl describe pod -n <ns> <pod>` (Events) and `kubectl logs -n <ns> <pod> --previous`.

See the Configuration Guide's *Configuration Pitfalls* section for setting-specific gotchas.

---

## Task 6 — Tear down [Automated]

On the **Deployments** page, open the deployment and click the **Trash** icon (**Delete**). Delete runs `terraform destroy`: it gracefully uninstalls Istio and the observability add-ons, removes the `istio-system` namespace, then tears down the GKE cluster, node pool, service account, VPC, firewall rules, and Cloud NAT created by this module. Delete is irreversible (the deployment record is retained for history).

If a deployment is stuck and the RAD platform can no longer manage it (for example after manual changes that conflict with the Terraform state), use **Purge** instead — it removes the deployment from RAD's records **without** destroying the cloud resources (it makes RAD forget the project). After a Purge, clean up any leftover resources manually.

---

## Summary

| Task | Type | Outcome |
|---|---|---|
| 1 — Deploy | Automated | Module provisions the VPC + GKE Standard cluster and installs Istio (sidecar or ambient) plus the observability stack |
| 2 — Access & verify | Manual | Connect to the cluster; control plane healthy; data-plane mode confirmed; a workload enrols into the mesh |
| 3 — Operate | Manual | Inspect control plane and gateway, change version/mode via Update, enforce strict mTLS, inspect proxy config |
| 4 — Observe | Manual | Use Kiali/Grafana/Jaeger/Prometheus; query Cloud Logging and Cloud Monitoring |
| 5 — Troubleshoot | Manual | Diagnose ingress IP, install, sidecar/ambient enrolment, mTLS, and pod issues |
| 6 — Tear down | Automated | Delete (Trash) uninstalls Istio and removes all module resources |
