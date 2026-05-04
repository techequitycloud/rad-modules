# Security

A consolidated view of the security controls the repo implements, what is intentionally omitted for lab simplicity, and the natural hardening path toward production.

## Controls in place

### Identity and access

- **SA impersonation** — `provider-auth.tf` modules never hold long-lived credentials; the provider mints a short-lived token (1800–3600s) for `var.resource_creator_identity`. See [devsecops](../practices/devsecops.md).
- **Workload Identity** — Bank_GKE and MC_Bank_GKE pods reach Cloud APIs via Workload Identity binding rather than mounted key files (`gke.tf` `workload_identity_config` block).
- **Least-privilege node SAs** — node pool service accounts hold only the four roles required for logging/monitoring plus `artifactregistry.reader`. See [kubernetes](./kubernetes.md).
- **No secrets in defaults** — `client_secret` (AKS_GKE) and `aws_secret_key` (EKS_GKE) have no defaults; sourced from environment variables at apply time.

### Network

- VPC-native pod and service ranges; private cluster nodes with Cloud NAT for egress.
- Additive firewall rules only — no `0.0.0.0/0` baseline sources on custom rules.
- Single public ingress per module (Istio Ingress Gateway or global HTTPS LB with Google-managed certificate).
- Connect Gateway for attached cluster API access instead of exposed AKS/EKS endpoints.

See [networking-zero-trust](./networking-zero-trust.md).

### Workload identity and mTLS

- Mesh-enforced mTLS between all workloads (SPIFFE-based SVID certificates).
- `PeerAuthentication` (open-source Istio) or ASM managed enforcement.
- `AuthorizationPolicy` for identity-based east-west access control.
- `RequestAuthentication` (JWT) for request-level identity at mesh ingress.

See [service-mesh](./service-mesh.md).

### State and audit

- Terraform state in GCS with versioning and object-level encryption; bucket not publicly readable.
- Deployed commit SHA recorded in `commit_hash.txt` per deployment for audit traceability.
- `/security` workflow in `AGENTS.md` defines a six-section audit checklist (IAM, secrets, network, GKE hardening, mesh, state) with the `gcloud` and `kubectl` commands to verify each gate.

### Secret Manager

`secretmanager.googleapis.com` is enabled in `modules/MC_Bank_GKE/main.tf`. Bank of Anthos uses Secret Manager to store database credentials rather than Kubernetes Secrets in plaintext — the Workload Identity binding gives pods access to the relevant secret versions. This pattern is available to any workload deployed on clusters with Workload Identity enabled.

## Controls not yet in place (production hardening path)

The following controls are absent by design for lab usability. Each is a well-defined addition:

| Control | Where to add | Notes |
|---|---|---|
| **Shielded Nodes** (Secure Boot, vTPM, integrity monitoring) | `shielded_instance_config` block in `gke.tf` | Prevents node-level boot attacks |
| **Binary Authorization** | `google_binary_authorization_policy` resource + `binary_authorization` block in `gke.tf` | Ensures only signed images run in the cluster |
| **Pod Security Admission** | `PodSecurity` namespace labels via `kubernetes_manifest` | Enforces baseline/restricted pod security standards |
| **VPC Service Controls** | Project-level `google_access_context_manager_service_perimeter` | Data perimeter around GCP APIs; prevents data exfiltration |
| **Cloud Armor** | `security_policy` attachment on `google_compute_backend_service` in `glb.tf` | WAF rules and DDoS protection on the global HTTPS LB |
| **Alerting on security events** | `google_monitoring_alert_policy` with log-based metrics | E.g., alert on `PeerAuthentication` violations or IAM policy changes |
| **Certificate Authority Service** | ASM `meshConfig.certificateAuthority` pointing to CAS | Customer-managed root CA for compliance-sensitive environments |

## Security review workflow

Running `AGENTS.md` `/security` is the project's definition-of-done for a security review of any module change. It covers all six domains above and provides the exact CLI commands to verify each gate.
