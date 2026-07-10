## 2024-07-10 - Hardcoded Windows VM Password in Migration_Center

**Vulnerability:** A hardcoded password (`m1grat10nc#nt#r`) was used for the local Windows RDP user `migrationcenter` in `modules/Migration_Center/windows_vm.tf`, `outputs.tf`, and various documentation files.
**Learning:** Hardcoded credentials even for "lab simplicity" violate zero-trust and least-privilege principles, exposing the RDP interface to immediate credential stuffing or unauthorized access if the external IP is known.
**Prevention:** Always generate passwords dynamically using the `random_password` provider and propagate them securely through Terraform state and outputs (marked as `sensitive = true`), rather than hardcoding them in scripts and documentation. Ensure `override_special = "!#$%&*()-_=+[]{}<>:?"` is used to avoid script injection issues with single quotes (`'`) in PowerShell strings.
