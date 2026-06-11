## 2024-05-24 - [CRITICAL] Hardcoded RDP password in Migration Center
**Vulnerability:** A hardcoded RDP password (`m1grat10nc#nt#r`) was found in `modules/Migration_Center/windows_vm.tf` and `modules/Migration_Center/outputs.tf`.
**Learning:** Hardcoding passwords in source code and exposing them in plain text in Terraform outputs is a critical security risk that allows anyone with repository access to connect to the VM.
**Prevention:** Always use `random_password` for generated passwords, or source them from Secret Manager. Mark the corresponding variables or outputs as `sensitive = true`.
