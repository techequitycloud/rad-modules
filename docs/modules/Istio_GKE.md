# Istio on GKE

<img src="https://storage.googleapis.com/rad-public-2b65/modules/Istio_GKE.png" alt="Istio on GKE" style={{maxWidth: "100%", borderRadius: "8px"}} />

This module stands up a **GKE Standard cluster** and installs the **open-source Istio service mesh** onto it — the upstream CNCF project that underpins Google Cloud Service Mesh and many other managed mesh offerings. Istio is installed directly with `istioctl`, so every configuration decision is transparent and inspectable, making this an ideal hands-on environment for platform engineers learning how a service mesh works from the ground up.

At deploy time you choose one of two data-plane architectures: **sidecar mode** (an Envoy proxy injected into every pod for full per-pod traffic control) or **ambient mode** (a shared per-node `ztunnel` proxy plus optional waypoint proxies, with much lower resource overhead). Alongside Istio, the module installs the full open-source observability stack — **Prometheus, Jaeger, Grafana, and Kiali** — so you can explore mesh telemetry immediately. This is a standalone infrastructure module: it provisions its own VPC, cluster, and networking, and does not build on any shared foundation.

This module is intended for **educational and evaluation purposes**.

---

## What Istio costs on RAD, and how that compares

**Istio on RAD costs about US$24 a month in your own project, and RAD charges no module fee at all for it.** It is a service mesh you install onto a cluster, not an application with its own data, so most of what makes other modules worth pausing rather than deleting does not apply here — see "How it compares" below for what that means in practice. Istio ships only as a GKE module on RAD; there is no Cloud Run variant, because Istio is infrastructure for a Kubernetes cluster.

### What you pay on RAD

| | In a Google Cloud project you own | In a project RAD manages for you |
|---|---|---|
| Module fee, once per deployment | no charge | no charge |
| Build time | A few credits per build | The same |
| Google Cloud running cost | Billed by Google to your own billing account, about **US$24.04 a month** for the default configuration (table below) | Metered hourly in credits; RAD publishes **43 credits a day** |
| Who owns what | You own the project and its billing; RAD deploys and updates it | RAD owns the project, with guardrails, quotas and budget alerts; you get console access, and a minimum purchased balance is held in reserve |

10 credits cost US$1 on a one-off top-up, less on a plan. In a project RAD manages, the
database, file server and network are shared by every application in the project, so a second
application does not add a second database.

**Default running cost in your own project** (us-central1, Google list prices):

| Resource (module default) | Per month |
|---|---|
| GKE Autopilot pod, 0.5x vCPU / 0.5 GiB | US$18.04 |
| Cloud NAT and networking | US$5.00 |
| Cloud Storage (add-ons, backups) | US$1.00 |
| GKE cluster management fee | shared across every GKE app in the project; $0 if this is your only cluster, else ~73 |
| **Total** | **about US$24.04** |

### How it compares

- Istio has no SaaS plan of its own — it is the open-source project behind several vendors' managed
  mesh products, not a hosted product itself. The nearest commercial comparison is a managed mesh
  add-on on top of a cluster you already run, rather than a standalone subscription, and we could not
  verify a current like-for-like price to quote here.
- This module's own pod is small (0.5 vCPU, 0.5 GiB) — the mesh control plane itself is light; what
  costs money is the cluster underneath it. A bare GKE Autopilot cluster of similar size, or a small
  Kubernetes cluster on a Hetzner CPX22 / DigitalOcean 2 vCPU/4 GB droplet (about $24/month), runs
  Istio with `istioctl` yourself — RAD's module automates exactly that installation and gives you
  Prometheus, Jaeger, Grafana and Kiali already wired in.
- Because this module is explicitly for **education and evaluation** rather than a production
  workload, the case for RAD here is less about saving money against a bare cluster and more about
  skipping the setup time of installing and wiring the observability stack by hand.

### Pause it for free: delete a RAD-managed project, restore it when you need it

If Istio runs in a project RAD manages for you and you expect to come back to it — a break
between courses, a seasonal lull, or simply not knowing yet whether you'll need it next
month — this is the better option, and it costs almost nothing.

Deleting a RAD-managed project unlinks its billing first, then asks Google to delete the
project outright: Google's own 30-day recoverable soft delete. Unlike deleting Istio as a
single module, this does not tear down the GKE cluster, mesh control plane and networking one by one — the whole project
simply stops, and nothing is charged while it waits, because billing is already unlinked.

Restoring, within 30 days and only by the project's owner, asks Google to undelete the
project and reattaches its billing account, then asks you to run Update on each deployment
to confirm everything came back. Because nothing was individually destroyed, that Update
finds the same resources already there — it is a check, not a rebuild, and an Update never
charges the module fee again. This costs only a handful of credits (under US$1) in build time
for a typical chain of deployments.

What this needs: you must own the project (not one RAD only manages billing for), you must
restore it yourself within 30 days — after that Google deletes it for good — and restoring is
admitted like creating a new project, so your purchased credit balance must still clear the
tier's floor (100 credits for the sandbox tier most use fits). Google says most services are
fully working again within 36 hours of a restore.

One real gap: nightly backups are written to a bucket inside the project, and that bucket has
Cloud Storage's soft-delete explicitly turned off, so it is very likely gone as soon as you
delete the project, even though the project itself is recoverable for 30 days. Istio holds no application data of its own — the mesh configuration is reapplied by Terraform on Update, not restored from a backup — so there is nothing of yours to lose by deleting the project either way.

### Pay only while you use it, the other way: delete and redeploy

In your own project, or once the 30-day window above has passed, the fallback is to delete
Istio outright and redeploy it later.

- **What a redeploy costs:** the module fee again, plus the builds — roughly the module fee
  shown above plus 3–6 credits of build time.
- **When it's worth it:** deleting saves money only once Istio would otherwise sit unused
  — but since there is no module fee, redeploying costs only a few credits of build time, so there is no real threshold to wait for: delete it whenever a session is over. There is no database or persistent data here, so deleting Istio removes its whole running cost on its own.
- **Keep data first.** Nightly backups are written to a bucket inside the deployment, and
  that bucket is deleted with it — copy the latest backup out (to Google Drive, or a bucket
  you keep) before deleting if you want to keep it.

### Lab sessions and Managed Environments

- **Lab sessions, for training.** A trainer runs a session for a class. Each participant gets
  the app in their own Google Cloud project for 15 minutes to 24 hours, within an allowance
  the trainer sets. Either the trainer funds every place, or each participant pays for their
  own. Everything is deleted when the session ends and unused credits go back to the trainer.
- **Managed Environments, for consultancies.** A partner runs the app for a client from a
  ring-fenced wallet it funds, and settles with the client directly. If the wallet runs low,
  billing pauses and the data is kept, so nobody receives an unexpected charge. At the end the
  partner hands the project over and the deployments become the client's own.
- Credits can be bought in more than 20 currencies, including XAF, XOF, NGN, GHS, KES and ZAR,
  by card, bank transfer or mobile money.

**Sources (8 October 2026):** Google Cloud list prices from the Cloud Billing Catalog API; RAD fees and the daily-credit estimate from [radmodules.dev/pricing](https://radmodules.dev/pricing); [Google Cloud: delete and restore projects](https://cloud.google.com/resource-manager/docs/delete-restore-projects) for the pause/restore mechanism. Prices change; check each source before relying on a figure.

---

## 1. Overview

| Capability | Google Cloud service | Notes |
|---|---|---|
| Compute | GKE Standard cluster | Single node pool with `node_count = 2` **per zone** across every UP zone in the region — 8 preemptible `e2-standard-2` nodes (16 vCPU) in a 4-zone region such as `us-central1`; you manage node configuration directly (not Autopilot) |
| Networking | VPC network + subnet | Custom-mode VPC, global routing, VPC-native (alias IP) with secondary ranges for pods and services |
| Egress | Cloud Router + Cloud NAT | Provisioned for the VPC, but the cluster is **not** private (no `private_cluster_config`), so nodes have external IPs and egress directly; the Istio install itself runs `local-exec` on the Terraform host, not on the nodes |
| Identity | Workload Identity + dedicated node service account | Least-privilege node SA; pods get a GCP identity without key files |
| Service mesh | Open-source Istio (via `istioctl`) | Sidecar **or** ambient mode, plus an Istio Ingress Gateway exposed via an external LoadBalancer |
| Observability | Prometheus, Jaeger, Grafana, Kiali | In-cluster open-source add-ons installed into `istio-system`; GKE Managed Prometheus also enabled at the cluster level |
| Security posture | GKE Security Posture, Gateway API | BASIC posture + vulnerability scanning; Gateway API standard channel enabled |

**Things to know up front:**

- **GKE Standard, not Autopilot.** You control the node pool, machine type, and cluster settings directly. The cluster permits the `NET_ADMIN` capability, which sidecar mode needs for its traffic-interception setup.
- **Sidecar is the default.** `install_ambient_mesh` defaults to `false` (sidecar mode). Set it to `true` for ambient mode. The mode is chosen at deploy time, and switching it requires a redeploy.
- **The Istio install runs as a deploy-time step.** After the cluster is created, the platform downloads `istioctl`, installs Istio with the selected profile, labels the `default` namespace for mesh enrolment, and installs the four observability add-ons. Transient add-on failures are logged as warnings and do not fail the deploy.
- **The Ingress Gateway gets a public IP.** Both modes install an `istio-ingressgateway` Service of type `LoadBalancer`, which provisions a GCP external load balancer. Allow 1–2 minutes after install for the IP to be assigned.
- **No demo application is provisioned.** The mesh and observability stack are installed, but no sample workload is deployed by the module. To explore traffic management you deploy your own workloads (or the Istio Bookinfo sample) into the `default` namespace, which is already labelled for mesh enrolment.
- **Preemptible nodes.** Nodes can be reclaimed with ~30 seconds notice. This keeps costs low for a learning environment but is not suitable for production.

---

## 2. Google Cloud Services & How to Explore Them

All `kubectl` / `istioctl` commands assume you have fetched cluster credentials first (the exact command is returned in the `cluster_credentials_cmd` [output](#5-outputs)):

```bash
gcloud container clusters get-credentials <gke_cluster> --region <region> --project <project>
```

### A. GKE Standard cluster

The cluster runs a single regional node pool of two preemptible `e2-standard-2` nodes **per zone** — 8 nodes in a 4-zone region such as `us-central1` — with VPC-native networking, Workload Identity, GKE Security Posture (BASIC), Managed Prometheus, and the Gateway API standard channel enabled. Check your regional CPU quota (16 vCPU for `e2-standard-2` × 8) before deploying.

- **Console:** Kubernetes Engine → Clusters → select the cluster → Details (release channel, version), Nodes (node pool), Security (Workload Identity, Security Posture).
- **CLI:**
  ```bash
  gcloud container clusters describe <gke_cluster> --region <region> --project <project> \
    --format="value(currentMasterVersion,releaseChannel.channel)"
  kubectl get nodes -o wide
  kubectl top nodes
  ```

### B. VPC networking, firewall, and Cloud NAT

A custom-mode VPC with one subnet (secondary ranges for pods and services), firewall rules, and a Cloud Router + Cloud NAT for outbound egress. The Istio install depends on NAT to download `istioctl` and add-on manifests.

- **Console:** VPC network → VPC networks (subnet + secondary ranges); VPC network → Firewall; Network services → Cloud NAT.
- **CLI:**
  ```bash
  gcloud compute networks subnets describe <subnet_name> --region <region> --project <project>
  gcloud compute firewall-rules list --project <project>
  gcloud compute routers get-nat-mapping-info cr1-<region> --region <region> --project <project>
  ```

### C. Istio control plane

`istiod` (the unified Pilot / Citadel / Galley control plane) and the Istio Ingress Gateway run in the `istio-system` namespace. `istiod` pushes Envoy/ztunnel configuration via the xDS protocol and acts as the mesh certificate authority.

- **Console:** Kubernetes Engine → Workloads → filter namespace `istio-system`.
- **CLI:**
  ```bash
  kubectl get all -n istio-system
  istioctl version
  istioctl verify-install
  istioctl proxy-status            # all proxies synced to the control plane
  istioctl analyze -A              # configuration validation
  ```

### D. Data plane — sidecar vs ambient

In **sidecar mode** an Envoy proxy is injected into each pod in a namespace labelled `istio-injection=enabled` (the module labels `default`). In **ambient mode** a `ztunnel` DaemonSet handles L4 mTLS per node for namespaces labelled `istio.io/dataplane-mode=ambient`, with optional waypoint proxies for L7.

- **CLI (sidecar):**
  ```bash
  kubectl get namespace default --show-labels        # expect istio-injection=enabled
  kubectl get mutatingwebhookconfiguration | grep istio
  istioctl proxy-config all <pod>                    # Envoy config for a pod's sidecar
  ```
- **CLI (ambient):**
  ```bash
  kubectl get namespace default --show-labels        # expect istio.io/dataplane-mode=ambient
  kubectl get daemonset ztunnel -n istio-system
  kubectl get pods -n istio-system -l app=ztunnel -o wide
  istioctl ztunnel-config workloads
  ```

### E. Istio Ingress Gateway

A standalone Envoy `Deployment` fronted by a `LoadBalancer` Service that provisions a GCP external load balancer — the entry point for traffic into the mesh.

- **Console:** Kubernetes Engine → Service & Ingress → `istio-ingressgateway`; Network services → Load balancing.
- **CLI:**
  ```bash
  kubectl get svc istio-ingressgateway -n istio-system
  # Read the external IP from the Service (the external_ip output is not reliably populated):
  kubectl get svc istio-ingressgateway -n istio-system \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}'; echo
  ```

### F. Observability stack

Prometheus, Jaeger, Grafana, and Kiali are installed into `istio-system`. They are reached by port-forwarding (the module does not expose them externally). GKE Managed Prometheus runs alongside them at the cluster level.

- **Console:** Monitoring → Metrics Explorer (Managed Prometheus / PromQL); Kubernetes Engine → Workloads (`istio-system`) for the add-on pods.
- **CLI:**
  ```bash
  kubectl get pods -n istio-system -l 'app in (prometheus,grafana,jaeger,kiali)'
  kubectl port-forward svc/kiali 20001:20001 -n istio-system        # http://localhost:20001
  kubectl port-forward svc/grafana 3000:3000 -n istio-system        # http://localhost:3000
  kubectl port-forward svc/tracing 16686:80 -n istio-system         # Jaeger UI
  kubectl port-forward svc/prometheus 9090:9090 -n istio-system
  ```

### G. Cloud Logging & Monitoring

Cluster system and workload logs flow to Cloud Logging; cluster and Managed Prometheus metrics flow to Cloud Monitoring.

- **Console:** Logging → Logs Explorer; Monitoring → Dashboards (GKE / Kubernetes).
- **CLI:**
  ```bash
  gcloud logging read 'resource.type="k8s_container" AND resource.labels.namespace_name="istio-system"' \
    --project <project> --limit 50
  ```

---

## 3. Behaviour

**Deploy-time sequence:**

1. Enable the required project APIs and wait for the Container API to activate.
2. Create the VPC, subnet (with pod and service secondary ranges), firewall rules, and Cloud Router + Cloud NAT — unless `create_network = false`, in which case the named existing network and subnet are used.
3. Create the GKE Standard cluster and a two-node preemptible node pool with a dedicated least-privilege node service account — unless `create_cluster = false`, in which case Istio installs onto the named existing cluster.
4. Run the Istio install as a deploy-time step: download `istioctl` for the requested `istio_version`, fetch cluster credentials, create the `istio-system` namespace, and install Istio with the selected profile.
5. Label the `default` namespace for mesh enrolment, then install the Prometheus, Jaeger, Grafana, and Kiali add-ons and run an installation verification.

**Sidecar mode (`install_ambient_mesh = false`, default):**

- Istio is installed with mesh identifiers and an autoscaled Ingress Gateway (min 2 / max 5 replicas, CPU target 80%). If that install path fails, the step falls back to a `minimal` profile install.
- The `default` namespace is labelled `istio-injection=enabled`. Pods created there receive an Envoy `istio-proxy` sidecar; the cluster permits `NET_ADMIN` so the sidecar can program traffic interception. **Existing pods must be restarted to pick up a sidecar.**

**Ambient mode (`install_ambient_mesh = true`):**

- Istio is installed with the `ambient` profile plus a LoadBalancer Ingress Gateway, and a resource quota is applied to protect node-critical pods.
- A `ztunnel` DaemonSet provides per-node L4 mTLS. The `default` namespace is labelled `istio.io/dataplane-mode=ambient` and a waypoint proxy is applied to it for L7 policy. Enrolment requires **no pod restart**.

**Runtime notes:**

- **Ingress IP.** After install, the Ingress Gateway's external IP takes 1–2 minutes to appear. The deploy logs print it; read it any time with `kubectl get svc istio-ingressgateway -n istio-system`. The module's `external_ip` output is best-effort and commonly reports `IP not available` — use the Service instead.
- **No sample application.** Although a `deploy_application` toggle is present, the current module does not provision a demo workload. Deploy your own services (or the Istio Bookinfo sample bundled with the downloaded Istio release) into the already-labelled `default` namespace to exercise traffic management, mTLS, and authorization policies.
- **Permissive mTLS by default.** The mesh accepts both plaintext and mTLS traffic until you apply a `STRICT` `PeerAuthentication` policy — intentional for incremental adoption.
- **Teardown.** Destroy runs a graceful uninstall that removes waypoints/labels, the observability add-ons, the Istio installation, and the `istio-system` namespace before the cluster and network are torn down. Cleanup steps are best-effort and never block the destroy.

---

## 4. Configuration Variables

Grouped exactly as they appear on the deployment platform. Module-metadata settings (Group 0) are managed by the platform and are not shown here.

### Group 1 — Project & Region

| Variable | Default | Description |
|---|---|---|
| `project_id` | _(required)_ | Destination GCP project where the cluster and mesh are deployed. Must already exist. |
| `tenant_id` | `demo` | Tenant identifier. Must be 1–20 lowercase alphanumeric characters or hyphens. **Currently has no effect** — it is validated but never referenced by any resource in this module; resource names use the deployment-id suffix instead. |
| `region` | `us-central1` | Region for the cluster, VPC, and all regional resources. Ensure sufficient quota. |

### Group 2 — Network

| Variable | Default | Description |
|---|---|---|
| `create_network` | `true` | Create a new VPC and subnet. Set `false` to install into an existing network/subnet. |
| `network_name` | `vpc-network` | Base name of the VPC. When `create_network = true` the VPC is created as `<network_name>-<deployment_id>` (a random suffix is appended); when `create_network = false` this is matched verbatim against the existing network. |
| `subnet_name` | `vpc-subnet` | Name of the subnet — created or referenced depending on `create_network`. |
| `ip_cidr_ranges` | `["10.132.0.0/16", "192.168.1.0/24"]` | CIDR blocks for the subnet ranges (only used when creating a network). The first is the primary node range. |

### Group 3 — GKE Cluster

| Variable | Default | Description |
|---|---|---|
| `create_cluster` | `true` | Create a new GKE Standard cluster. Set `false` to install Istio onto an existing cluster. |
| `gke_cluster` | `gke-cluster` | Name of the cluster — created or referenced depending on `create_cluster`. |
| `release_channel` | `REGULAR` | GKE release channel: `RAPID`, `REGULAR`, `STABLE`, or `NONE` (manual upgrades). |
| `pod_cidr_block` | `10.62.128.0/17` | Secondary range for pod IPs. Must not overlap the node or service ranges. |
| `service_cidr_block` | `10.64.128.0/20` | Secondary range for Service ClusterIPs. Must not overlap the node or pod ranges. |

### Group 4 — Istio Features

| Variable | Default | Description |
|---|---|---|
| `istio_version` | `1.30.3` | Open-source Istio version to install (major.minor.patch). Must be supported by the chosen release channel. |
| `install_ambient_mesh` | `false` | `false` installs sidecar mode (Envoy per pod); `true` installs ambient mode (per-node ztunnel + optional waypoints). |

---

## 5. Outputs

| Output | Description |
|---|---|
| `deployment_id` | Echoes the `deployment_id` **input**, not the generated suffix. When the input is left at its default (`null`) this output is empty even though resources are still named with an auto-generated random suffix. |
| `project_id` | The destination project ID. |
| `cluster_credentials_cmd` | Ready-to-run `gcloud container clusters get-credentials` command for the cluster. |
| `external_ip` | **Always** reports `IP not available` — it reads `scripts/app/external_ip.txt`, a file this module never creates. Read the IP from the `istio-ingressgateway` Service (or the deploy logs) instead. |

---

## 6. Configuration Pitfalls & Sensible Defaults

> Risk: **Critical** (data loss / outage / security) — **High** (service degraded) —
> **Medium** (cost or partial degradation) — **Low** (minor).

| Setting | Sensible value | Risk | Consequence if wrong |
|---|---|---|---|
| `pod_cidr_block` / `service_cidr_block` / `ip_cidr_ranges` | non-overlapping ranges | Critical | Overlapping secondary ranges (with each other or peered/on-prem networks) break cluster creation or cause routing conflicts that are hard to undo. |
| `install_ambient_mesh` | chosen once at deploy | High | The mode is fixed at install time; switching between sidecar and ambient after deploy requires tearing the mesh down and reinstalling. |
| `istio_version` | a real released tag (e.g. `1.30.3`) | High | An unavailable or unsupported version fails the `istioctl` download/install, leaving the cluster without a mesh. |
| `create_cluster` / `gke_cluster` | match the real target | High | With `create_cluster = false`, an incorrect `gke_cluster` name fails the existing-cluster lookup and the install aborts. |
| `create_network` with existing network | correct `network_name` / `subnet_name` | High | A wrong existing network/subnet name fails the lookup, or places the cluster in an unintended network. |
| Ingress IP expectations | read from the Service, not `external_ip` | Medium | Relying on the `external_ip` output (often `IP not available`) causes confusion; the LoadBalancer IP is always on the `istio-ingressgateway` Service. |
| `release_channel` | `REGULAR` | Medium | `RAPID` pulls in early Kubernetes versions that may not be validated against the chosen `istio_version`; `NONE` disables automatic patching. |
| Preemptible nodes (fixed) | acceptable for labs only | Medium | Both nodes can be reclaimed simultaneously, briefly making the control plane and gateway unavailable. Not for production. |
| Expecting a built-in demo app | deploy your own workload | Low | The module installs the mesh only; nothing serves traffic until you deploy a workload into the `default` namespace. |

---

For a hands-on walkthrough of deploying, verifying, operating, observing, and tearing down this module — including exploring sidecar vs ambient mode and the observability stack — see the **[Istio on GKE lab guide](../labs/Istio_GKE.md)**.
