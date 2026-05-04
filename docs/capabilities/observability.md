# Observability

Every GKE module ships a working metrics, traces, and dashboards stack. There is no "later set up monitoring" step.

## Open-source observability stack

`modules/Istio_GKE/istiosidecar.tf` and `modules/Istio_GKE/istioambient.tf` install the canonical Istio observability add-ons as part of the mesh install:

- **Prometheus** — metrics scraping
- **Grafana** — dashboards
- **Jaeger** — distributed tracing
- **Kiali** — service-graph and mesh-config UI

These run inside the cluster.

## Managed observability via ASM

For Cloud Service Mesh deployments, `modules/Bank_GKE/asm.tf` and `modules/MC_Bank_GKE/asm.tf` enable the GKE Hub `service_mesh` feature. The managed control plane routes telemetry into:

- **Cloud Monitoring** — metrics
- **Cloud Trace** — traces
- **Cloud Logging** — logs

No in-cluster Prometheus deployment is needed.

## SLOs

`modules/Bank_GKE/monitoring.tf` defines `google_monitoring_slo` resources for all nine Bank of Anthos services (`accounts-db`, `balancereader`, `contacts`, `frontend`, `ledger-db`, `ledgerwriter`, `loadgenerator`, `transactionhistory`, `userservice`). Each SLO measures CPU limit utilization over a 5-minute rolling window against a 95% goal on a daily calendar period. SLOs are versioned alongside the workload they measure and gated by `var.enable_monitoring`. The Bank_GKE workflow in `AGENTS.md` documents how to add a new SLO.

The [sre](../practices/sre.md) practice page is the consumer perspective.

## Alerting

`monitoring.tf` defines `google_monitoring_service` and `google_monitoring_slo` resources, but does not currently define alerting policies or notification channels. Adding burn-rate alerts on the existing SLOs would be a natural next step — a `google_monitoring_alert_policy` with a `condition_threshold` on the SLO burn rate, linked to a `google_monitoring_notification_channel`, following the same `for_each = toset(local.monitoring_services)` pattern already used.

## Distributed tracing context propagation

Bank of Anthos services propagate trace context using the **W3C Trace Context** (`traceparent`) header, which both Jaeger (open-source Istio) and Cloud Trace (ASM) understand natively. The mesh sidecar / ztunnel does not automatically propagate headers across hops — each service must forward the incoming `traceparent` header on outbound calls. This is the most common reason traces appear broken at service boundaries when first deploying a new workload.

## Diagnostic commands

`AGENTS.md` `/troubleshoot` documents the standard operational queries:

```bash
gcloud container fleet mesh describe --project=<project>
istioctl verify-install
istioctl proxy-status
kubectl get mci -n bank-of-anthos
kubectl get pods --all-namespaces
```

## Logs from null_resource provisioners

`null_resource` `local-exec` output is the install log. Provisioners use `set -eo pipefail` on create to fail fast and `set +e` on destroy to finish cleanup despite errors. Provisioner stdout shows the path of any on-disk artefacts (e.g. the Bank of Anthos tarball at `.terraform/bank-of-anthos/`).
