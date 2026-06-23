<!--
Target:   Dev.to
Audience: Developers and platform engineers who want to learn how Istio actually works, hands-on
Voice:    Hands-on, conversational, practical, show-don't-tell
Tags:     #googlecloud #kubernetes #gke #istio #servicemesh #ambientmesh #devops
Goal:     Show that running open-source Istio yourself — sidecar or ambient — is approachable and inspectable; CTA to deploy the Istio_GKE RAD module.
-->

# Run Open-Source Istio on GKE Yourself — Sidecar or the New Ambient Mesh, with Prometheus, Jaeger, Grafana, and Kiali Wired Up

Most "service mesh on Kubernetes" tutorials hand you a managed mesh: the control plane lives somewhere you can't see, sidecar injection "just happens," and you never actually learn how any of it works. That's great for shipping. It's not great for *understanding*.

The **Istio_GKE** RAD module goes the other way on purpose. It stands up a **GKE Standard cluster** and installs **upstream, open-source Istio** onto it with `istioctl` — the same CNCF project that sits underneath Google Cloud Service Mesh and most managed mesh offerings. Nothing is hidden behind a fleet feature. The control plane runs in *your* cluster, in the `istio-system` namespace, where you can `kubectl get` it, break it, and watch it recover. It's the difference between reading about a mesh and operating one.

It's a standalone, educational module: point it at a GCP project and you get the VPC, the cluster, Istio, and a full open-source observability stack. Let's look at what lands.

## What you get

- **A GKE Standard cluster** — two preemptible `e2-standard-2` nodes in one node pool. You own the node config (this is deliberately *not* Autopilot), and the cluster permits the `NET_ADMIN` capability that sidecar mode needs to program traffic interception.
- **A dedicated VPC** — custom-mode network, one subnet with VPC-native secondary ranges for pods and services, plus Cloud Router + Cloud NAT so the private nodes can reach GitHub and container registries to pull `istioctl` and the add-ons.
- **Open-source Istio**, installed via `istioctl` at the version you choose (`istio_version`, default `1.24.2`), with `istiod` and an Istio Ingress Gateway fronted by an external LoadBalancer.
- **Your choice of data plane** — sidecar mode (Envoy per pod) *or* ambient mode (per-node `ztunnel` + optional waypoint proxies). One variable picks it.
- **The full OSS observability stack** — **Prometheus, Jaeger, Grafana, and Kiali** installed into `istio-system`, plus GKE Managed Prometheus running at the cluster level.

## The one decision that defines the deployment: sidecar vs ambient

This is the interesting part, and the module makes both modes a single toggle: `install_ambient_mesh`.

**Sidecar mode (`false`, the default)** is classic Istio. The `default` namespace is labelled `istio-injection=enabled`, and every pod you create there gets an Envoy `istio-proxy` injected next to it. Maximum per-pod control — and the proof is in the readiness column:

```bash
kubectl get namespace default --show-labels   # expect istio-injection=enabled
kubectl get pods -n default                    # app pods come up 2/2 (app + istio-proxy)
istioctl proxy-config all <pod>                # inspect a sidecar's Envoy config
```

One gotcha worth knowing up front: **existing pods don't get a sidecar retroactively.** Injection happens at admission, so anything already running has to be restarted to pick up its proxy.

**Ambient mode (`true`)** is Istio's newer sidecar-less data plane. Instead of a proxy per pod, a `ztunnel` DaemonSet handles L4 mTLS per *node*, and the `default` namespace is labelled `istio.io/dataplane-mode=ambient` with a waypoint proxy applied for L7 policy. Much lower overhead, and — the part people love — **enrolment requires no pod restart:**

```bash
kubectl get namespace default --show-labels    # expect istio.io/dataplane-mode=ambient
kubectl get daemonset ztunnel -n istio-system
istioctl ztunnel-config workloads
```

**The catch you must internalize:** the mode is chosen at deploy time and is effectively fixed. Switching between sidecar and ambient after the fact means tearing the mesh down and reinstalling. So pick the one you actually want to explore before you apply.

## Deploying it

The module is in the RAD Lab catalog. Non-interactively via the launcher:

```bash
python3 rad-launcher/radlab.py \
  -m Istio_GKE -a create \
  -p my-mgmt-project -b my-mgmt-project-radlab-tfstate \
  -f /path/to/my.tfvars
```

Or straight OpenTofu/Terraform from the module directory:

```bash
cd modules/Istio_GKE
tofu init
tofu apply -var="project_id=my-gcp-project"
```

After the cluster is up, the install runs as a deploy-time step: it downloads `istioctl` for your chosen version, fetches cluster credentials, creates `istio-system`, installs Istio with the selected profile, labels `default` for mesh enrolment, and installs the four add-ons. Transient add-on failures are logged as warnings and don't fail the deploy — so check what actually landed afterward rather than assuming.

## Poke at it

First, confirm the control plane is healthy. This is the stuff you *can't* do with a managed mesh, and it's the whole point of running Istio yourself:

```bash
istioctl version
istioctl verify-install
istioctl proxy-status     # every proxy synced to istiod
istioctl analyze -A       # validate your mesh config
```

Find the Ingress Gateway's address. **Important: don't trust the `external_ip` output** — it's best-effort and frequently reports `IP not available`. Read it from the Service instead:

```bash
kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'; echo
```

(Give it 1–2 minutes after install for the LoadBalancer IP to be assigned.)

Then explore the observability stack. The module doesn't expose these externally — you port-forward:

```bash
kubectl port-forward svc/kiali 20001:20001 -n istio-system     # topology graph: http://localhost:20001
kubectl port-forward svc/grafana 3000:3000 -n istio-system     # dashboards
kubectl port-forward svc/tracing 16686:80 -n istio-system      # Jaeger traces
kubectl port-forward svc/prometheus 9090:9090 -n istio-system  # raw metrics
```

## Things worth knowing before you rely on it

This is an **education and evaluation** module, not a production mesh. The honest edges:

- **No demo app is deployed.** There's a `deploy_application` toggle, but the current module installs the mesh and observability only — it does *not* provision a sample workload. To see traffic, latency, and mTLS in Kiali, deploy your own services or the **Istio Bookinfo** sample (it ships inside the Istio release that got downloaded) into the already-labelled `default` namespace.
- **mTLS is permissive by default.** The mesh accepts both plaintext and mTLS until you apply a `STRICT` `PeerAuthentication`. That's intentional — it's how you do incremental adoption — but don't assume "STRICT everywhere" without setting it.
- **Preemptible nodes.** Both nodes can be reclaimed with ~30 seconds' notice, which briefly takes the control plane and gateway down. Great for keeping a lab cheap; not for anything you care about.
- **Overlapping CIDRs will ruin your day.** `pod_cidr_block`, `service_cidr_block`, and the subnet ranges must not overlap each other (or any peered network). Overlap breaks cluster creation or causes routing conflicts that are painful to undo.

## Why it's worth deploying

If you want to actually *understand* Istio — how injection works, what `istiod` does, what an Envoy config looks like, how ambient's ztunnel differs from sidecars — you need a mesh you can take apart, not one hidden behind an API. This module gives you exactly that, plus the full OSS telemetry stack to watch it work, in one apply.

Deploy it, run `istioctl proxy-status`, port-forward Kiali, then drop Bookinfo into `default` and watch the graph light up. That's the moment the diagrams turn into a system.

👉 **Istio_GKE** lives in the RAD Lab modules catalog. Grab it, deploy it, and explore the [module deep-dive](../../modules/Istio_GKE.md) and the [hands-on lab guide](../../labs/Istio_GKE.md).
