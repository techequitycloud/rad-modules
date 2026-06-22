Run a security audit of the rad-modules repository: $ARGUMENTS

If $ARGUMENTS names a module (e.g. "Istio_GKE", "EKS_GKE"), scope all checks to that
module directory. Otherwise scan every module under `modules/`.

This complements the Trivy config scan in CI (which catches generic misconfigurations) by
checking the conventions and multi-cloud credential rules specific to rad-modules.

End with the structured summary at the bottom.

---

**CHECK 1 — HARDCODED CLOUD CREDENTIALS**

Grep all .tf files in scope for credential fields assigned a literal value:
  client_secret, aws_secret_key, aws_access_key, aws_secret_access_key,
  password, api_key, access_token, secret_key, private_key, service_account_key

Flag any assigned a quoted literal (≥8 chars). Safe forms (do NOT flag):
  = var.<name>    = local.<name>    = data.<...>    = random_password.<...>.result    = ""

Also flag any `variable "<credential>"` block with a non-empty hardcoded `default`. This is
the cardinal rule: Azure (`ARM_*`) and AWS (`AWS_*`) credentials are supplied at runtime via
env vars or tfvars, never baked into the module. Severity: HIGH.

---

**CHECK 2 — SENSITIVE FLAGS**

Every credential variable (client_secret, tenant_id, subscription_id, client_id,
aws_secret_key, aws_access_key, and any *_secret / *_key / *password*) must set
`sensitive = true` so the value is redacted in plan output and logs. Report any that don't.
Severity: MEDIUM.

---

**CHECK 3 — SERVICE ACCOUNT & IAM LEAST PRIVILEGE**

Read every .tf that creates `google_project_iam_member`, `google_project_iam_binding`,
`google_service_account`, or grants roles (gke.tf, iam.tf, hub.tf, etc.).

For each role granted to a service account or to `trusted_users`, flag anything broader than
needed:
  roles/owner            — always flag (HIGH)
  roles/editor           — always flag (HIGH)
  roles/iam.securityAdmin, roles/iam.serviceAccountAdmin — flag unless justified (MEDIUM)
  roles/container.admin  — check whether roles/container.developer suffices (LOW)
  roles/storage.admin    — check whether objectAdmin/objectViewer suffices (LOW)

Report the SA/binding, the broad role, and a narrower alternative.

---

**CHECK 4 — IMPERSONATION SAFETY**

For Pattern B modules (provider-auth.tf present):
  a) The `google_service_account_access_token` data source must be gated on
     `length(var.resource_creator_identity) != 0` (count or conditional), so the module
     still works under plain ADC when no SA is supplied.
  b) `access_token` must never be hardcoded.
  c) Token `lifetime` should be bounded (≤ "3600s"). Flag anything longer.

---

**CHECK 5 — API ENABLEMENT INVARIANT**

Every `google_project_service` must set `disable_dependent_services = false` and
`disable_on_destroy = false`, and must not use `lifecycle { prevent_destroy = true }`.
A destroy that disables shared APIs is a denial-of-service against co-tenant modules.
Severity: HIGH (data-integrity / availability).

---

**CHECK 6 — NETWORK EXPOSURE**

  a) Firewall rules (`google_compute_firewall`): flag any `source_ranges = ["0.0.0.0/0"]`
     opening management ports (22, 3389, 6443, 10250). Note Istio/LB ingress 80/443 is
     usually intentional but call it out.
  b) GKE clusters: check whether `enable_private_nodes` / a private endpoint is configured;
     flag clusters with a fully public control plane unless the module's purpose requires it.
  c) `master_authorized_networks` — flag clusters exposing the API server to 0.0.0.0/0.

---

**CHECK 7 — DESTROY-PROVISIONER SAFETY**

For `null_resource` blocks with `local-exec` provisioners:
  a) Destroy provisioners (`when = destroy`) should use `set +e` and `--ignore-not-found` /
     `|| echo "Warning..."` so a partial state never blocks destroy.
  b) Triggers must capture every variable the destroy provisioner reads (only
     `self.triggers.*` is available at destroy time) — flag a destroy provisioner that
     references `var.*` directly.

These are reliability/safety issues that can strand resources or credentials. Severity: LOW.

---

**CHECK 8 — PUBLIC ACCESS DEFAULT**

Note each module's `public_access` default (catalog visibility) and `enable_purge` default.
These are platform-policy choices, not vulnerabilities — report them as INFO so a reviewer
can confirm they are intended.

---

**SUMMARY**

```
Security Scan: <scope>
======================
CHECK 1  Hardcoded Cloud Credentials   — N finding(s)
CHECK 2  Sensitive Flags               — N finding(s)
CHECK 3  SA / IAM Least Privilege       — N finding(s)
CHECK 4  Impersonation Safety          — N finding(s)
CHECK 5  API Enablement Invariant      — N finding(s)
CHECK 6  Network Exposure              — N finding(s)
CHECK 7  Destroy-Provisioner Safety    — N finding(s)
CHECK 8  Public Access Defaults        — N finding(s) (INFO)

Total: N actionable issue(s).
```

For each finding include: severity (HIGH / MEDIUM / LOW / INFO), file and line, what is
wrong, and the recommended fix.
