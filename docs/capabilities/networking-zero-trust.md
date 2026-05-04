# Networking & Zero Trust

The repo applies a consistent zero-trust posture: identity-based mTLS between workloads, no public node IPs, additive firewalls, and a single public ingress per module.

## VPC-native networking

Every GKE module (`modules/Istio_GKE/network.tf`, `modules/Bank_GKE/network.tf`, `modules/MC_Bank_GKE/network.tf`) creates a VPC with a subnet that has secondary IP ranges for pods and services. The GKE cluster uses these via `ip_allocation_policy`, so pod traffic is native VPC traffic, not overlay.

## Private nodes with Cloud NAT

Cluster nodes have no public IPs. Outbound traffic to the internet (image pulls, package installs in `null_resource` provisioners) goes through a Cloud Router + Cloud NAT created in `network.tf`. Inbound traffic enters only via the cluster's load balancer.

## Single ingress per module

- `modules/Istio_GKE/` — the Istio Ingress Gateway is the only public entry point. The `/security` workflow in `AGENTS.md` checks that no other service exposes a public IP.
- `modules/Bank_GKE/glb.tf` and `modules/MC_Bank_GKE/glb.tf` — a global HTTPS load balancer with a Google-managed certificate fronts Bank of Anthos. The certificate references a domain configured via `templates/managed_certificate.yaml.tpl`.

## Additive firewall rules

GKE manages its own firewall rules; the modules avoid `0.0.0.0/0` baseline sources on any custom rule. The `/security` workflow in `AGENTS.md` audits firewall rule sources and ports.

## Mesh identity is the workload trust boundary

mTLS between workloads, identity-based authorization (`AuthorizationPolicy`), and JWT-based request authentication are all enforced at the mesh layer. See [service-mesh](./service-mesh.md).

## Connect Gateway for attached clusters

`modules/AKS_GKE/` and `modules/EKS_GKE/` register the cluster with GCP Fleet, so cluster API access goes through Connect Gateway rather than exposing the AKS / EKS API endpoint publicly. See [hybrid-cloud-fleet](./hybrid-cloud-fleet.md).

## Multi-cluster routing

`modules/MC_Bank_GKE/` uses Multi-Cluster Ingress and Multi-Cluster Services behind a single global LB. Clients hit the nearest healthy region; mesh identity follows the request across clusters.
