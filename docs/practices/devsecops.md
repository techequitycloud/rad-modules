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

## Provider supply-chain security

All modules pin provider versions in `versions.tf` with `~>` constraints to prevent unexpected major-version upgrades. Running `tofu providers lock -platform=linux_amd64` generates a `.terraform.lock.hcl` file with cryptographic hashes for each provider binary; committing this file means CI can detect if a provider binary changes between runs. Periodically updating the lock file and reviewing the diff is the recommended cadence for staying current without silent supply-chain drift.

## Audit logging

Cloud Audit Logs (Admin Activity and Data Access) should be enabled for the APIs used by each module — Container, Compute, IAM, GCS, and GKE Hub. Admin Activity logs are on by default; Data Access logs for GCS and IAM require explicit project-level configuration. Exporting these logs to a long-term sink (a dedicated Cloud Logging bucket or BigQuery dataset in the management project) provides the forensic trail needed for compliance reviews. The `/security` checklist in `AGENTS.md` includes a `gcloud logging` command to verify audit log sinks are configured.

## What is not here

Policy-as-code admission control (OPA/Gatekeeper, Policy Controller) and Binary Authorization for container image verification are not currently included in any module. These provide a workload-level enforcement layer above what mTLS and IAM supply. They are natural next steps for a production-hardened cluster posture.
