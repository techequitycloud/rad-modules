## 2024-05-22 - [Multiple Security Issues Found]
**Vulnerability:** Found multiple security issues including hardcoded credentials (e.g. `password` creation logic) and `roles/owner` bindings in `scripts/gcp-cr-mesh/gcp-cr-mesh.sh`, `scripts/gcp-istio-security/gcp-istio-security.sh`, `scripts/gcp-istio-traffic/gcp-istio-traffic.sh`, and `scripts/gcp-m2c-vm/gcp-m2c-vm.sh`. Also found overly broad `roles/storage.objectAdmin` in GKE modules.
**Learning:** Only one security issue should be fixed per session to keep PRs focused and manageable. The GKE module IAM overly broad permission issue was prioritized and fixed in this session.
**Prevention:** These issues will be addressed in future sessions.
