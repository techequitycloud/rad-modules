# Service Mesh

The single largest theme in this repository: four of five modules deploy a mesh, and a fifth lab connects Cloud Run to one. Both open-source Istio and Google's managed Cloud Service Mesh are represented.

## Open-source Istio on GKE

`modules/Istio_GKE/` installs upstream Istio on a GKE Standard cluster. The user picks **sidecar mode** (`istiosidecar.tf`) or **ambient mode** (`istioambient.tf`) via `var.install_ambient_mesh`. The two files are mutually exclusive — one runs `count = var.install_ambient_mesh ? 0 : 1`, the other its inverse — so a mesh is only ever installed once.

The sidecar installer pipes a custom `IstioOperator` YAML into `istioctl install -y -f -` to fix HPA naming (`hpaSpec.scaleTargetRef.name = istio-ingressgateway`). Removing this block reintroduces a known install error.

### Sidecar vs ambient: when to pick which

| Dimension | Sidecar | Ambient |
|---|---|---|
| L7 traffic policy | Per-pod Envoy proxy | ztunnel (L4) + optional waypoint proxy (L7) |
| Resource overhead | Each pod gets a proxy container | Shared per-node ztunnel; waypoints are opt-in |
| Pod restarts on install | Required (proxy injection) | Not required |
| Feature completeness | Full Istio API surface | Subset; maturing rapidly |
| Lab suitability | Mature, well-documented | Lower overhead for demo clusters |

For production clusters where per-pod overhead matters, ambient mode is worth evaluating. For teams learning the full Istio API surface (traffic management, security primitives), sidecar mode exposes more knobs.

The observability add-ons are installed in the same `null_resource`: Prometheus, Grafana, Jaeger, Kiali. See [observability](./observability.md).

## Cloud Service Mesh on a single cluster

`modules/Bank_GKE/asm.tf` enables the GKE Hub `service_mesh` feature and binds it to the cluster's Hub membership, then runs `gcloud container fleet mesh update` to install ASM (managed Istio). The managed control plane runs in GCP, not in the cluster.

## Fleet-wide Cloud Service Mesh

`modules/MC_Bank_GKE/asm.tf` enables the same Hub feature once and creates a `google_gke_hub_feature_membership` for each cluster, so all clusters in the fleet share a single mesh. Cross-cluster traffic flows over Multi-Cluster Services.

`modules/MC_Bank_GKE/mcs.tf` contains the destroy `null_resource` that deletes MCI/MCS objects across all clusters before Terraform removes the fleet feature — a step Terraform's graph cannot do on its own.

## Cloud Run on the mesh

`scripts/gcp-cr-mesh/gcp-cr-mesh.sh` is an interactive lab that puts a Cloud Run service behind Cloud Service Mesh via a serverless NEG, a global `INTERNAL_SELF_MANAGED` backend service, and an `HTTPRoute` (imported via `gcloud network-services http-routes import`). This uses the **Traffic Director / Network Services API** routing model, not the Kubernetes Gateway API CRDs. See [serverless](./serverless.md).

## Mesh on attached clusters

`modules/AKS_GKE/modules/attached-install-mesh/` and the EKS equivalent install ASM on a non-GCP cluster. Not invoked automatically by the parent module; callers opt in. See [multicloud](./multicloud.md).

## Mesh CA / certificate authority

- **Open-source Istio** — Istiod acts as the mesh CA, issuing SPIFFE-compliant workload certificates with a 24-hour validity and automatic rotation. No external CA is configured.
- **Cloud Service Mesh** — the managed control plane handles certificate issuance and rotation. `gcloud container fleet mesh describe` reports the CA type and certificate status. Neither deployment integrates Google Certificate Authority Service for a custom root CA; that is the production path for compliance-sensitive environments that require a customer-managed PKI.

## mTLS

- Open-source Istio: `PeerAuthentication` resources can enforce `STRICT` mTLS across the mesh namespace.
- Cloud Service Mesh: managed control plane enforces mTLS by default; verify with `gcloud container fleet mesh describe`.

## Traffic management

`scripts/gcp-istio-traffic/` is a hands-on lab covering the primitives applied in the modules: weighted splits, header-based routing, fault injection, sidecar egress, port-level load balancing, timeouts, retries. These use the classic Istio API (`VirtualService`, `DestinationRule`, `Gateway`). The Cloud Run mesh lab (`gcp-cr-mesh`) uses the Network Services `HTTPRoute` resource instead — a separate API surface for Traffic Director-managed routing.

## Security primitives

`scripts/gcp-istio-security/` walks through `PeerAuthentication`, `RequestAuthentication` (JWT), and `AuthorizationPolicy`. The [devsecops](../practices/devsecops.md) practice page references this for the security-audit angle.

## Multi-cluster traffic

`modules/MC_Bank_GKE/glb.tf` reserves a global static IP; `modules/MC_Bank_GKE/deploy.tf` enables `google_gke_hub_feature.multiclusteringress_feature` and applies the MultiClusterIngress / MultiClusterService manifests to a config cluster. The result is a single global HTTPS load balancer routing traffic to Bank of Anthos pods on whichever cluster is healthy.
