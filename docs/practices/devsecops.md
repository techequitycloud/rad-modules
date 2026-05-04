# DevSecOps

Security is shifted left across this repository: encoded in module defaults, gated by IAM impersonation, enforced at the mesh layer, and audited by a dedicated review workflow.

## Service-account impersonation

The three GKE-based modules use the impersonation pattern in `provider-auth.tf`. The caller never holds long-lived credentials; the provider mints a short-lived access token (1800s for Istio_GKE, 3600s for Bank_GKE) for each `apply`, scoped to the platform service account `var.resource_creator_identity`.

## Secrets stay out of variables

`SKILLS.md` §6 invariant: no secrets in variable defaults. AKS_GKE's `client_secret` and EKS_GKE's `aws_secret_key` are inputs but never have defaults; credentials are sourced from environment variables (`ARM_CLIENT_SECRET`, `AWS_SECRET_ACCESS_KEY`) at apply time.

## mTLS by default

Workload-to-workload identity and encryption are mesh-enforced. See [service-mesh](../capabilities/service-mesh.md) for the modes (`PeerAuthentication` `STRICT`, ASM-managed control plane) and the security-primitive lab at `scripts/gcp-istio-security/`.

## Least-privilege node pools

GKE node pools use a dedicated cluster service account with only the four roles needed for logging and monitoring — never the Compute Engine default SA, never `roles/owner` or `roles/editor`. See [kubernetes](../capabilities/kubernetes.md).

## Network hardening

VPC-native ranges, private nodes with Cloud NAT, additive firewall rules, single ingress per module, Google-managed certificates on the public LB. See [networking-zero-trust](../capabilities/networking-zero-trust.md).

## Standing security review

`AGENTS.md` `/security` workflow defines a six-section audit checklist (IAM, secrets, network, GKE hardening, mesh, state) plus the `gcloud` and `kubectl` commands needed to verify each gate. Running this checklist is the project's definition-of-done for a security review of any module.

## State integrity

Terraform state in GCS with versioning and object-level encryption; never local for shared environments. Bucket IAM is not publicly readable. `.terraform/` is in `.gitignore` so cached provider data and credentials never reach the repo. See [infrastructure-as-code](../capabilities/infrastructure-as-code.md).
