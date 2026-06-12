## 2024-10-24 - Fix hardcoded Windows RDP password in Migration_Center

**Vulnerability:** A hardcoded password ("m1grat10nc#nt#r") was discovered in the `windows-startup-script-ps1` metadata for the Windows VM in `modules/Migration_Center/windows_vm.tf`. Another hardcoded password for PostgreSQL was also observed in `modules/Container_Migration/vms.tf` but left for a separate PR.
**Learning:** Hardcoded passwords in instance metadata or startup scripts expose credentials to anyone who can view the instance metadata or the Terraform state/source code.
**Prevention:** Use `random_password` resources to generate secure, dynamic passwords and pass them to scripts via single-quoted interpolations, marking the corresponding Terraform outputs as `sensitive = true`.
