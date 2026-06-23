<!--
Target:   Dev.to
Audience: Developers and platform engineers curious about service mesh and microservices on GKE
Voice:    Hands-on, conversational, practical, show-don't-tell
Tags:     #googlecloud #kubernetes #gke #istio #servicemesh #microservices #devops
Goal:     Show that a full mTLS microservices banking app on a managed mesh is approachable; CTA to deploy the Bank_GKE RAD module.
-->

# Deploy a Real Microservices Bank on GKE — with mTLS, a Managed Service Mesh, and SLOs You Didn't Have to Wire Up

Service mesh has a reputation: powerful, and a pain to run. You install `istiod`, you babysit the control plane, you debug sidecar injection, you wonder why your pod is `1/1` when it should be `2/2`. Most people bounce off it before they ever see the payoff.

The **Bank_GKE** RAD module skips all of that. It stands up a GKE Autopilot cluster, registers it in a fleet, turns on **Cloud Service Mesh** (Google-managed Istio — *no `istiod` in your cluster*), and deploys [Bank of Anthos](https://github.com/GoogleCloudPlatform/bank-of-anthos) — Google's open-source reference banking app — with every pod automatically wrapped in an Envoy sidecar and every hop encrypted with mTLS. Then it registers a Cloud Monitoring SLO for each service.

It's a standalone, educational module: one GCP project with billing, and you get the whole stack. Let's look at what actually lands.

## What you get

- **A GKE Autopilot cluster** — no node pools to size or patch. (Flip one variable for a Standard cluster with a 2-node Spot pool if you want to see the node-level wiring instead.)
- **Bank of Anthos v0.6.7** — nine microservices in three tiers, plus two PostgreSQL StatefulSets and a load generator:
  - `frontend` (Python web UI)
  - `userservice`, `contacts`, `accounts-db` (accounts + Postgres)
  - `ledgerwriter`, `balancereader`, `transactionhistory`, `ledger-db` (the transaction ledger + Postgres)
  - `loadgenerator` — drives synthetic traffic so your dashboards and SLOs actually have data
- **Cloud Service Mesh**, managed by Google, with automatic sidecar injection and mTLS for all in-namespace traffic.
- **A dedicated VPC** — subnet with VPC-native secondary ranges for pods and services, Cloud Router + Cloud NAT for egress, and the firewall rules to make it all work.
- **Observability for free** — Managed Service for Prometheus on the cluster, one Cloud Monitoring service **and a CPU-utilization SLO per workload**, logs to Cloud Logging, and distributed traces to Cloud Trace (the sidecars emit them — you write zero instrumentation code).

The polyglot bit is the fun part for a demo: Python *and* Java services talking to each other over HTTP, authenticating users with an RSA-signed JWT stored as a Kubernetes Secret. It behaves like a real system because it is built like one.

## The one trick that makes the mesh painless

Here's the thing most service-mesh tutorials make hard, and this module makes invisible.

With `enable_cloud_service_mesh = true`, the mesh is enabled as a **fleet feature** with `MANAGEMENT_AUTOMATIC`. Google runs the Istio control plane outside your cluster. The module labels the application namespace:

```
istio.io/rev=asm-managed
```

That label is the whole game. Any pod admitted into the `bank-of-anthos` namespace gets an Envoy sidecar injected automatically. No `istioctl`, no manual patching, no control-plane pods eating your cluster budget.

The proof is the readiness column. After deploy:

```bash
kubectl get pods -n bank-of-anthos
```

Every pod shows `2/2` — one container is the app, the second is the `istio-proxy` sidecar. Want to confirm it's really there?

```bash
kubectl get pods -n bank-of-anthos \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.containers[*]}{.name}{" "}{end}{"\n"}{end}'
```

You'll see `istio-proxy` listed alongside each app container. That `2/2` is your mTLS-everywhere posture, established without touching a single line of application code.

## Deploying it

The module ships in the RAD Lab catalog. Non-interactively via the launcher:

```bash
python3 rad-launcher/radlab.py \
  -m Bank_GKE -a create \
  -p my-mgmt-project -b my-mgmt-project-radlab-tfstate \
  -f /path/to/my.tfvars
```

Or straight OpenTofu/Terraform from the module directory:

```bash
cd modules/Bank_GKE
tofu init
tofu apply -var="project_id=my-gcp-project"
```

**Heads-up: first deploys take ~30–45 minutes, and that's by design.** The module is deliberately *mesh-first*: it enables the GKE Hub and mesh APIs, grants the GKE Hub service agent its roles, registers the fleet membership, enables the mesh feature, and then **polls until the membership and mesh control plane both report `ACTIVE`** before it deploys the app. If it deployed the workloads first, sidecar injection would race the control plane and you'd get pods without proxies. The wait is the module doing the annoying ordering correctly so you don't have to.

## Poke at it

Find the address the app is actually served on (the upstream `frontend` Service is type `LoadBalancer`):

```bash
kubectl get svc frontend -n bank-of-anthos \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Open that IP in a browser — it's plain HTTP on port 80 (more on that below) — and you've got a working bank with login, balances, and transactions, traffic already flowing from the load generator.

Then go look at what the mesh gives you for free:

- **Kubernetes Engine → Service Mesh** in the Console: a live topology graph with per-service latency, traffic, and error rates. Golden signals, zero instrumentation.
- **Monitoring → Services → SLOs**: one SLO per workload (95% CPU-limit-utilization goal, daily window). A ready-made SLO framework to learn burn rates on.
- **Trace → Trace list**: distributed traces stitched together by the sidecars.

```bash
gcloud container fleet mesh describe --project "$PROJECT"
gcloud monitoring services list --project "$PROJECT"
```

## Things worth knowing before you rely on it

This is an **education and demo** module, not a production banking system. A few honest edges:

- **The frontend is plain HTTP on a public IP.** The module reserves a global static IP (`bank-of-anthos`) and enables the Gateway API add-on, but it does *not* wire up an HTTPS load balancer, a managed certificate, or a domain. For anything past a demo, put HTTPS and/or IAP in front of it yourself.
- **`enable_config_management` is a no-op today.** The inputs exist for forward compatibility but aren't wired to any resource. Leave it `false`.
- **Deploying into a locked-down/lab project?** Cloud Service Mesh pulls in the Anthos/Fleet API family. In some restricted projects (e.g. trial/lab accounts) those APIs require accepting the Cloud Terms of Service first, and the deploying identity needs `roles/owner`. If an apply dies early on API enablement, that's almost always why — not the module.
- **The databases are ephemeral.** `accounts-db` and `ledger-db` hold all the account and transaction data and are deleted with the cluster on teardown. It's a demo; don't put anything real in it.

## Why it's a great thing to deploy

If you've wanted to *understand* service mesh, fleet management, and SLO-based observability — not just read about them — this is one of the fastest ways to get a real, multi-service, mTLS-encrypted system in front of you that you can break, inspect, and rebuild. The hard parts (control-plane lifecycle, injection ordering, monitored-service/SLO wiring) are handled, so you can spend your time on the concepts instead of the yak-shaving.

Deploy it, run `kubectl get pods -n bank-of-anthos`, watch every pod come up `2/2`, and open the Service Mesh topology graph. That's the moment service mesh stops being scary.

👉 **Bank_GKE** lives in the RAD Lab modules catalog. Grab it, deploy it, and explore the [module deep-dive](../../modules/Bank_GKE.md) and the [hands-on lab guide](../../labs/Bank_GKE.md).
