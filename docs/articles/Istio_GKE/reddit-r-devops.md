<!--
Target:   Reddit r/devops
Audience: Practitioners who hate marketing; want the honest what/why/gotchas
Voice:    Plain, no hype, first-person, discussion-starting; invites correction
Tags:     (Reddit has no tags; flair suggestion) Flair: Open Source / Tooling
Goal:     Honest writeup of an OSS reference module that installs self-managed Istio (sidecar OR ambient) on GKE; spark discussion, link the module.
-->

# A reference module that installs *open-source* Istio on GKE — you run istiod, pick sidecar OR ambient, full Prometheus/Jaeger/Grafana/Kiali stack included

Posting because most "try a service mesh" guides hand you a managed mesh where the control plane is invisible, and you never actually learn how Istio works. This goes the other way: self-hosted upstream Istio on a cluster you control. Not selling anything — it's an educational OSS module in the RAD Lab catalog. What it does + honest gotchas below.

**What it does**

One `tofu apply` stands up:

- GKE **Standard** cluster (2x preemptible `e2-standard-2`, single node pool — deliberately not Autopilot so you control node config; cluster permits `NET_ADMIN` for sidecar interception)
- Dedicated VPC, subnet w/ VPC-native secondary ranges, Cloud Router + NAT (nodes need egress to pull istioctl + add-ons)
- **Open-source Istio** installed via `istioctl` at the version you pick (`istio_version`, default 1.24.2). `istiod` runs in *your* `istio-system` namespace — you can inspect/break/debug it
- **Sidecar OR ambient** data plane via one var (`install_ambient_mesh`)
- Istio Ingress Gateway behind an external LoadBalancer
- **Prometheus, Jaeger, Grafana, Kiali** installed into `istio-system`, plus GKE Managed Prometheus at the cluster level

**The part that's actually nice**

Nothing's hidden. You get the real toolbox:

```
istioctl verify-install
istioctl proxy-status      # are all proxies synced to the control plane
istioctl analyze -A        # validate mesh config
```

Sidecar mode labels `default` with `istio-injection=enabled`, pods come up 2/2. Ambient mode runs a `ztunnel` DaemonSet for per-node L4 mTLS, labels the ns `istio.io/dataplane-mode=ambient`, adds a waypoint for L7 — and enrolment needs **no pod restart**. Being able to deploy both on the same cluster and compare is the actual value here.

**Gotchas / things I'd want to know first**

- **Mode is fixed at deploy time.** Switching sidecar <-> ambient = tear the mesh down and reinstall. No in-place migration. Pick before you apply.
- **No app is deployed.** There's a `deploy_application` toggle but it's currently a no-op — you get the mesh + observability, no workload. Bring your own or drop in the Istio **Bookinfo** sample (it's inside the Istio release that got downloaded) into the already-labelled `default` ns.
- **Don't trust the `external_ip` output.** It's best-effort and usually says `IP not available`. Read the gateway IP off the Service instead: `kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`. Give it 1-2 min to populate.
- **mTLS is permissive by default.** Plaintext + mTLS both accepted until you apply a STRICT `PeerAuthentication`. Intentional for incremental adoption, but don't assume strict.
- **Sidecars don't apply retroactively.** Existing pods need a restart to get an `istio-proxy`. (Ambient doesn't have this problem — another reason the comparison is interesting.)
- **Preemptible nodes.** Both can get reclaimed at once, briefly taking istiod + gateway down. Lab only.
- **Watch your CIDRs.** pod/service/subnet ranges must not overlap each other or peered networks, or cluster creation breaks.
- **Add-on failures are warnings, not errors.** Transient add-on install failures get logged and the deploy still succeeds — so verify what actually landed afterward.

**Why bother**

It's the least painful way I've found to get *self-managed* Istio in front of you to actually learn from — debug istiod yourself, compare sidecar vs ambient hands-on, and watch the full OSS telemetry stack (topology graph, traces, dashboards) light up from proxy data. Good for learning the mesh internals a managed quickstart hides, or for forming a real opinion before you commit to managed-vs-self-hosted in production.

Genuinely curious what folks here think: for teams *learning* a mesh, is self-hosting Istio worth the extra operational rope vs starting on a managed one? And separately — anyone moved a real workload from sidecars to **ambient** yet? Is the no-restart enrolment and lower overhead living up to it in practice, or are the waypoint/L7 ergonomics still rough?

Module + docs are in the RAD Lab `rad-modules` repo under `Istio_GKE`: the [module deep-dive](../../modules/Istio_GKE.md) and a step-by-step [lab guide](../../labs/Istio_GKE.md).
