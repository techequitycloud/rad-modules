# DevSecOps

Security is shifted left across this repository: it is encoded in module defaults, gated by IAM impersonation, enforced at the mesh layer with mTLS, and audited by a dedicated review workflow.

## Service-account impersonation, not key files

The three GKE-based modules use the impersonation pattern in `provider-auth.tf` (`modules/Istio_GKE/provider-auth.tf`, `modules/Bank_GKE/provider-auth.tf`, `modules/MC_Bank_GKE/provider-auth.tf`):

```hcl
data "google_service_account_access_token" "default" {
  count                  = length(var.resource_creator_identity) != 0 ? 1 : 0
  provider               = google.impersonated
  target_service_account = var.resource_creator_identity
  lifetime               = "1800s"
}
```

The caller never holds long-lived credentials. The provider mints a short-lived access token (1800s for Istio_GKE, 3600s for Bank_GKE) for each `apply`, scoped to the platform service account.

## Secrets stay out of variables

`SKILLS.md` §6 invariant: **No secrets in variable defaults**. AKS_GKE's `client_secret` and EKS_GKE's `aws_secret_key` are inputs but never have defaults; credentials are sourced from environment variables (`ARM_CLIENT_SECRET`, `AWS_SECRET_ACCESS_KEY`) at apply time. The Security workflow in `AGENTS.md` codifies this as an audit checkpoint.

## Mesh-enforced mTLS by default

- `modules/Istio_GKE/` installs open-source Istio with `PeerAuthentication` capable of `STRICT` mode mTLS across the mesh namespace.
- `modules/Bank_GKE/asm.tf` and `modules/MC_Bank_GKE/asm.tf` enable Cloud Service Mesh, whose managed control plane enforces mTLS by default; verify with `gcloud container fleet mesh describe`.

`scripts/gcp-istio-security/gcp-istio-security.sh` is a guided lab that walks through:

- Mutual TLS modes
- `PeerAuthentication`
- `RequestAuthentication` (JWT)
- `AuthorizationPolicy`
- Traffic mirroring and circuit breaking

It serves as both training material and a verification harness for the mesh security posture.

## Least-privilege node pools

GKE node pools in `modules/Bank_GKE/gke.tf`, `modules/Istio_GKE/gke.tf`, and `modules/MC_Bank_GKE/gke.tf` use a dedicated cluster service account with only:

- `roles/logging.logWriter`
- `roles/monitoring.metricWriter`
- `roles/monitoring.viewer`
- `roles/stackdriver.resourceMetadata.writer`

Not the Compute Engine default SA, and explicitly **not** `roles/owner` or `roles/editor`. The Security workflow in `AGENTS.md` audits exactly this list.

## Network hardening

- VPC-native networking with IP alias ranges (`network.tf` in each GKE module).
- Cloud Router + Cloud NAT so nodes can egress without public IPs.
- Firewall rules are additive — no `0.0.0.0/0` baseline.
- Bank_GKE / MC_Bank_GKE expose workloads only through a Google-managed HTTPS load balancer (`modules/Bank_GKE/glb.tf`, `modules/MC_Bank_GKE/glb.tf`) with a Google-managed certificate.

## Standing security review process

`AGENTS.md` `/security` workflow defines a six-section audit checklist (IAM, secrets, network, GKE hardening, mesh, state) plus the `gcloud` / `kubectl` commands needed to verify each gate. Running this checklist against any module is the project's definition-of-done for a security review.

## State integrity

`SKILLS.md` §6 and `AGENTS.md` security workflow require Terraform state in GCS with versioning and object-level encryption, never local for shared environments, and bucket IAM that is not publicly readable. `.terraform/` is in `.gitignore` so cached provider data and credentials never reach the repo.
